#![cfg(windows)]
use mdm_torrent::{Config, Phase, Source, Torrents, librqbit};
use std::time::Duration;

async fn finished(engine: &Torrents, hash: &str) {
    tokio::time::timeout(Duration::from_secs(30), async {
        while engine.stats(hash).unwrap().phase != Phase::Finished {
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    })
    .await
    .expect("local torrent transfer timed out");
}

#[tokio::test]
async fn local_transfer_pause_and_remove_keep_the_file() {
    let tmp = tempfile::tempdir().unwrap();
    let source = tmp.path().join("source");
    std::fs::create_dir(&source).unwrap();
    let bytes: Vec<_> = (0..300_000).map(|i| (i % 251) as u8).collect();
    std::fs::write(source.join("fixture.bin"), &bytes).unwrap();
    let made = librqbit::create_torrent(
        &source,
        librqbit::CreateTorrentOptions {
            name: Some("fixture"),
            trackers: Vec::new(),
            piece_length: Some(16 * 1024),
        },
        &librqbit::spawn_utils::BlockingSpawner::new(1),
    )
    .await
    .unwrap();
    let torrent = made.as_bytes().unwrap().to_vec();
    let config = |name: &str| Config {
        offline: true,
        dht: false,
        upnp: false,
        lsd: false,
        ..Config::new(tmp.path().join(name))
    };
    let seed = Torrents::start(config("seed-state")).await.unwrap();
    let receiver = Torrents::start(config("receiver-state")).await.unwrap();
    let hash = seed
        .add(&torrent, &source, None, Vec::new(), false)
        .await
        .unwrap();
    finished(&seed, &hash).await;
    let meta = receiver
        .metadata(&Source::File(torrent.clone()), Duration::from_secs(5), None)
        .await
        .unwrap();
    let destination = tmp.path().join("received");
    let got = receiver
        .add(
            &torrent,
            &destination,
            Some(vec![0]),
            vec![seed.listen_addr().unwrap()],
            true,
        )
        .await
        .unwrap();
    tokio::time::timeout(Duration::from_secs(10), async {
        while receiver.stats(&got).unwrap().phase != Phase::Paused {
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    })
    .await
    .expect("torrent did not reach paused state");
    receiver.resume(&got).await.unwrap();
    finished(&receiver, &got).await;
    let path = destination.join(&meta.files[0].path);
    assert_eq!(std::fs::read(&path).unwrap(), bytes);
    receiver.pause(&got).await.unwrap();
    receiver.stop().await;
    drop(receiver);
    let receiver = Torrents::start(config("receiver-state")).await.unwrap();
    assert!(
        receiver.has(&got),
        "saved transfer must survive session restart"
    );
    tokio::time::timeout(Duration::from_secs(10), async {
        while receiver.stats(&got).unwrap().phase == Phase::Checking {
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
    })
    .await
    .unwrap();
    assert_eq!(
        receiver.stats(&got).unwrap().phase,
        Phase::Paused,
        "restart must preserve user pause"
    );
    assert_eq!(std::fs::read(&path).unwrap(), bytes);
    receiver.remove(&got, false).await.unwrap();
    assert!(path.is_file());
    assert!(!receiver.has(&got));
    receiver.stop().await;
    seed.stop().await;
}

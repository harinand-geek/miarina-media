//! Native messaging host of the Miarina Media extension (Chrome, Edge): a
//! ping answers the connection test; a link opens its analysis in the app.
fn main() {
    let ok = (|| -> std::io::Result<()> {
        let message = miarina_browser_bridge::read_message(&mut std::io::stdin().lock())?;
        match message.url {
            Some(url) => open(&url),
            None => Ok(()),
        }
    })()
    .is_ok();
    // stdout is strictly the native messaging protocol, even on errors.
    let _ = miarina_browser_bridge::write_response(&mut std::io::stdout().lock(), ok);
}

#[cfg(windows)]
fn open(url: &str) -> std::io::Result<()> {
    miarina_browser_bridge::open_in_app(url)
}

#[cfg(not(windows))]
fn open(_: &str) -> std::io::Result<()> {
    Err(std::io::Error::other("Windows only"))
}

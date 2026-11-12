# Inventaire des licences — modules libVLC 3.0.24 livrés (DEP-03)

Date : 2026-11-12 · Lot : suite de L05 · Statut : **relevé factuel**, sans conclusion juridique : à faire valider par le propriétaire du produit avant publication.

## Ce qui est livré

`tools/libvlc/<empreinte>/` de l'installeur Windows (décision 0005, fiche L05) : `libvlc.dll`, `libvlccore.dll`, `COPYING.txt`, `AUTHORS.txt` et **280 modules** `plugins/<dossier>/lib<nom>_plugin.dll`, tirés de l'archive officielle `vlc-3.0.24-win64.zip` (SHA-256 `fcf30850…6323`) par `crates/download-engine/src/components.rs` (`libvlc_keep`).

Licence déclarée de Miarina Media : **GPL-3.0-only** (`Cargo.toml`, `LICENSE.md`).

## Méthode

Script (non versionné, relancé à chaque montée de version) sur l'archive des sources officielles `vlc-3.0.24.tar.xz` (SHA-256 `e7cab503d1d7d5849b89d2cf0e1ee60d0ef6d012407791b644b9cfc0cc225fdf`, identique à celle publiée par VideoLAN) :

1. pour chaque module livré, retrouver ses fichiers sources (`lib<nom>_plugin_la_SOURCES` des `modules/**/Makefile.am`) ;
2. lire la notice en tête de chaque source (4 Ko) : « Lesser General Public License » → LGPL, « General Public License » → GPL, notices permissives (MIT, BSD, ISC…) → permissive, sinon « à vérifier » ;
3. retenir pour le module la notice la plus contraignante de ses sources ;
4. relever les bibliothèques tierces liées (`lib<nom>_plugin_la_LIBADD` : `$(XXX_LIBS)`), qui ont leurs propres licences (non classées ici).

Limites : une notice d'en-tête n'est pas une analyse juridique ; les bibliothèques tierces compilées dans les modules par les « contribs » de VideoLAN (FFmpeg, libass, FreeType…) ne sont pas couvertes par ce relevé ; un module peut aussi inclure des en-têtes d'autres dossiers.

## Résultat

| Notice des sources du module | Modules |
|---|---|
| LGPL (2.1 ou ultérieure) | 255 |
| GPL — toutes avec « version 2 ou toute version ultérieure » | 17 |
| Permissive | 1 (`text_renderer/libsapi_plugin.dll`) |
| À vérifier (notice non reconnue) | 6 |
| Source non retrouvée | 1 (`audio_filter/libscaletempo_pitch_plugin.dll`, construit à partir des sources de `scaletempo`) |

### Modules dont des sources portent une notice GPL (v2 ou ultérieure)

| Module | Sources concernées |
|---|---|
| `audio_filter/libdolby_surround_decoder_plugin.dll` | `channel_mixer/dolby.c` |
| `audio_filter/libheadphone_channel_mixer_plugin.dll` | `channel_mixer/headphone.c` |
| `audio_filter/libmono_plugin.dll` | `channel_mixer/mono.c` |
| `codec/libt140_plugin.dll` | `codec/t140.c` |
| `demux/libmpc_plugin.dll` | `demux/mpc.c` |
| `demux/libreal_plugin.dll` | `demux/real.c` |
| `logger/libfile_logger_plugin.dll` | `logger/file.c` |
| `misc/libaudioscrobbler_plugin.dll` | `misc/audioscrobbler.c` |
| `misc/libexport_plugin.dll` | `misc/playlist/export.c`, `html.c`, `m3u.c`, `xspf.c` |
| `misc/liblogger_plugin.dll` | `misc/logger.c` |
| `misc/libstats_plugin.dll` | `misc/stats.c` |
| `misc/libvod_rtsp_plugin.dll` | `misc/rtsp.c` |
| `spu/libremoteosd_plugin.dll` | `spu/remoteosd_rfbproto.h` |
| `video_chroma/libi420_rgb_mmx_plugin.dll` | `video_chroma/i420_rgb_mmx.h` |
| `video_filter/libdeinterlace_plugin.dll` | `deinterlace/yadif.h`, `yadif_template.h` |
| `video_filter/libhqdn3d_plugin.dll` | `video_filter/hqdn3d.h` |
| `video_filter/librotate_plugin.dll` | `video_filter/rotate.c` |

### À vérifier à la main

`access/libcdda_plugin.dll`, `access/liblive555_plugin.dll`, `audio_filter/libspatializer_plugin.dll`, `codec/libopus_plugin.dll`, `demux/libts_plugin.dll`, `misc/libfingerprinter_plugin.dll`, `audio_filter/libscaletempo_pitch_plugin.dll`.

### Bibliothèques tierces liées par des modules livrés (licences à relever dans les contribs)

AOM (`aom`), ARCHIVE (`archive`), ARIBB24 (`aribsub`, `ts`), ARIBB25 (`aribcam`), AVCODEC / AVFORMAT / AVUTIL (`avcodec`, `postproc`), CACA (`caca`), DAV1D (`dav1d`), DVBPSI (`ts`), FLAC (`flac`), FONTCONFIG / FREETYPE / FRIBIDI / HARFBUZZ (`freetype`, `libass`), GCRYPT (`cdda`, `rtp`, `remoteosd`), GNUTLS (`gnutls`), KATE / TIGER (`kate`), LIBASS (`libass`), LIBCDDB (`cdda`), LIBVORBIS / OGG (`ogg`), LIBXML2 (`xml`), MAD (`mad`), MPG123 (`mpg123`), OGGSPOTS (`oggspots`), OPUS (`opus`), POSTPROC (`postproc`), SAMPLERATE (`samplerate`), SPATIALAUDIO (`spatialaudio`), SPEEX (`speex`), SPEEXDSP (`speex_resampler`), SWSCALE (`swscale`), TAGLIB (`taglib`), THEORA (`theora`), VORBIS (`vorbis`), VPX (`vpx`), ZVBI (`zvbi`). Le module `codec/libfaad_plugin.dll` (notice LGPL de ses propres sources) s'appuie sur la bibliothèque FAAD2, dont le projet amont publie sous GPL : à confirmer avec les sources des contribs.

## À décider avant publication (propriétaire du produit)

1. Si l'ensemble livré convient tel quel au regard de la GPL-3.0-only de Miarina (notices relevées : LGPL-2.1+ et GPL-2.0+), ou s'il faut retirer des modules (la plupart des 17 ci-dessus ne servent pas à la lecture locale : journaux, statistiques, export de playlist, audioscrobbler, VOD RTSP, OSD distant ; `deinterlace` sert aux vidéos entrelacées).
2. Comment fournir les sources correspondantes : la notice livrée (`THIRD-PARTY-TOOLS.txt`) pointe déjà l'archive des sources de VLC 3.0.24 et la page des sources de VideoLAN ; les sources des contribs sont à pointer aussi.
3. Relancer ce relevé à chaque changement de version de libVLC.

## Indépendance vis-à-vis d'un VLC installé

Mesure du 2026-11-12 sur la machine de développement (où VLC 3.0.24 est installé dans `Program Files\VideoLAN`) : pendant la lecture d'un MKV par la build de recette, **78 modules VLC** sont chargés dans le processus, **tous** depuis `tools\libvlc\fcf30850371ad10c\` de l'application, **aucun** depuis `Program Files\VideoLAN` (chargement par chemin complet, `LOAD_WITH_ALTERED_SEARCH_PATH`, `VLC_PLUGIN_PATH`). Parmi eux, `logger/libfile_logger_plugin.dll` (notice GPL) est chargé par défaut par libVLC. Un essai sur une machine **sans** VLC reste à faire avec l'installeur complet.

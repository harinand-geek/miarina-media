//! What the browser's address bar opens (ported from the retired Tauri app,
//! tag `archive/tauri-react-client`): a
//! web address opens the page, anything else is searched. Only http(s)
//! pages are ever opened.

use url::Url;

/// Search page for text that is not a web address.
pub const SEARCH_URL: &str = "https://www.google.com/search";

/// Longest text the address bar accepts.
const MAX_ADDRESS: usize = 4096;

#[derive(Debug, PartialEq, Eq)]
pub enum AddressError {
    /// Empty or too long.
    NotAWebAddress,
    /// Not http(s) (file:, javascript:, …).
    Unsupported,
}

pub fn resolve_address(input: &str) -> Result<Url, AddressError> {
    let text = input.trim();
    if text.is_empty() || text.len() > MAX_ADDRESS {
        return Err(AddressError::NotAWebAddress);
    }
    if text.contains("://") {
        let url = Url::parse(text).map_err(|_| AddressError::Unsupported)?;
        return web_only(url);
    }
    if looks_like_address(text)
        && let Ok(url) = Url::parse(&format!("https://{text}"))
        && url.host_str().is_some()
    {
        return web_only(url);
    }
    Ok(search_url(text))
}

pub fn search_url(query: &str) -> Url {
    Url::parse_with_params(SEARCH_URL, [("q", query)]).expect("constant search URL")
}

/// `youtube.com`, `m.example.org/x`, `localhost:8080` — not `youtube` or
/// `two words`.
fn looks_like_address(text: &str) -> bool {
    if text.chars().any(char::is_whitespace) {
        return false;
    }
    let host = text.split(['/', '?', '#']).next().unwrap_or("");
    let host = host.rsplit_once('@').map_or(host, |(_, h)| h);
    let name = host.split(':').next().unwrap_or("");
    name == "localhost"
        || name.rsplit_once('.').is_some_and(|(left, tld)| {
            !left.is_empty() && tld.len() >= 2 && tld.chars().all(|c| c.is_ascii_alphabetic())
        })
        || name.parse::<std::net::Ipv4Addr>().is_ok()
}

fn web_only(url: Url) -> Result<Url, AddressError> {
    match url.scheme() {
        "http" | "https" if url.host_str().is_some() => Ok(url),
        _ => Err(AddressError::Unsupported),
    }
}

pub fn is_web(url: &str) -> bool {
    url.starts_with("https://") || url.starts_with("http://")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn addresses_open_pages() {
        assert_eq!(
            resolve_address("example.org").unwrap().as_str(),
            "https://example.org/"
        );
        assert_eq!(
            resolve_address(" http://a.org/x ").unwrap().as_str(),
            "http://a.org/x"
        );
        assert_eq!(
            resolve_address("m.youtube.com/watch?v=x").unwrap().as_str(),
            "https://m.youtube.com/watch?v=x"
        );
        assert!(resolve_address("localhost:8080").is_ok());
        assert!(resolve_address("192.168.1.10/media").is_ok());
    }

    #[test]
    fn other_text_is_searched() {
        for query in [
            "youtube",
            "chanson malgache 2026",
            "c'est quoi Sintel?",
            "v1.2",
        ] {
            let url = resolve_address(query).unwrap();
            assert_eq!(url.host_str(), Some("www.google.com"), "{query}");
            let q: Vec<_> = url.query_pairs().collect();
            assert_eq!(q[0].1, query);
        }
    }

    #[test]
    fn only_web_pages_are_opened() {
        for bad in [
            "",
            "file:///C:/x",
            "javascript://alert(1)",
            "ftp://a.org",
            "intent://x",
        ] {
            assert!(resolve_address(bad).is_err(), "{bad}");
        }
        // Without "://", a scheme-like text is just a search.
        assert_eq!(
            resolve_address("javascript:alert(1)").unwrap().host_str(),
            Some("www.google.com")
        );
    }
}

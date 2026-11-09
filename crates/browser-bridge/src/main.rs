fn main() {
    let result = (|| {
        let request = miarina_browser_bridge::read_request(&mut std::io::stdin().lock())?;
        miarina_browser_bridge::enqueue(&miarina_browser_bridge::default_inbox()?, request)
    })();
    // stdout is strictly the native messaging protocol, even on errors.
    let _ = miarina_browser_bridge::write_response(&mut std::io::stdout().lock(), result.is_ok());
}

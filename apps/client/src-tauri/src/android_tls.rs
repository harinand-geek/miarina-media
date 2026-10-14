//! Android: reqwest checks certificates with the system trust store through
//! `rustls-platform-verifier`, which needs the JVM and the app context before
//! the first HTTPS request (otherwise it panics).

pub fn init() -> Result<(), String> {
    let ctx = ndk_context::android_context();
    // SAFETY: tao fills `ndk_context` with the process JavaVM and the activity
    // context before the app's entry point runs.
    let vm = unsafe { jni::JavaVM::from_raw(ctx.vm().cast()) };
    vm.attach_current_thread(|env| {
        // SAFETY: `ctx.context()` is a global reference valid for the process.
        let context = unsafe { jni::objects::JObject::from_raw(env, ctx.context().cast()) };
        rustls_platform_verifier::android::init_with_env(env, context)
    })
    .map_err(|e| format!("TLS verifier initialization failed: {e:?}"))
}

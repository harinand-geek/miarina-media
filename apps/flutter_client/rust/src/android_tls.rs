//! Android: reqwest checks certificates with the system trust store through
//! `rustls-platform-verifier`, which needs the JVM and the app context before
//! the first HTTPS request (otherwise it panics). The Tauri app got them from
//! tao; here `NativeBridge.initTls(context)` (Kotlin) hands them over once,
//! before Flutter starts.

use jni::EnvUnowned;
use jni::objects::{JClass, JObject};

#[unsafe(no_mangle)]
pub extern "system" fn Java_org_miarina_media_NativeBridge_initTls<'caller>(
    mut unowned_env: EnvUnowned<'caller>,
    _class: JClass<'caller>,
    context: JObject<'caller>,
) {
    unowned_env
        .with_env(|env| -> Result<(), jni::errors::Error> {
            rustls_platform_verifier::android::init_with_env(env, context)
        })
        .resolve::<jni::errors::ThrowRuntimeExAndDefault>()
}

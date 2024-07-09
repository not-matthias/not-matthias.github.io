+++
title = "Kernel Driver with Rust in 2022"
date = "2022-08-16"

[taxonomies]
tags=["windows kernel", "rust"]
+++

A lot has changed since I wrote my first blog post on [how to write kernel drivers with Rust](https://not-matthias.github.io/posts/kernel-driver-with-rust/). I learned more about the language and worked on more projects. The goal of this blog post is to keep you updated on the changes from the last 2 years. 

# Kernel Logging

When I originally wrote [Kernel Printing with Rust](https://not-matthias.github.io/posts/kernel-printing-with-rust/), I had never heard or used the [log](https://crates.io/crates/log) crate. It's very powerful and you should definitely use it instead of some custom macros. 

By using the `log` crate, we can easily switch between a [kernel logger](https://crates.io/crates/kernel-log) or [serial port logger](https://crates.io/crates/com_logger). Here's an implementation using my [kernel-log](https://crates.io/crates/kernel-log) crate:

```rust
#![no_std]

use kernel_log::KernelLogger;

#[no_mangle]
pub extern "system" fn DriverEntry() -> u64 {
    KernelLogger::init(LevelFilter::Info).expect("Failed to initialize logger");

    log::warn!("This is an example message.");

    0 /* STATUS_SUCCESS */
}
```

# Crates

Over the time, I realized that creating a new kernel driver is quite a lot of effort. That's why I decided to extract the generic parts and turn them into crates. 

- **[kernel-build](https://github.com/not-matthias/kernel-build-rs)**: Automatically sets the linker paths. You don't have to copy [`build.rs`](https://github.com/not-matthias/kernel-build-rs/blob/main/build.rs) into every project anymore. 
- **[kernel-alloc](https://github.com/not-matthias/kernel-alloc-rs)**: When you want to use [`Vec`](https://doc.rust-lang.org/stable/alloc/vec/struct.Vec.html) or [`Box`](https://doc.rust-lang.org/stable/alloc/boxed/struct.Box.html) in the kernel.
- **[kernel-log](https://github.com/not-matthias/kernel-log-rs)**: When you want to use the `log` crate in the kernel.

# Ecosystem

There are still no official bindings. :( But there's an open [GitHub Issue](https://github.com/microsoft/win32metadata/issues/401) for that. Feel free to add a comment and upvote it. 

I also found the [ntapi](https://crates.io/crates/ntapi) crate, which has a `kernel` feature. They don't have all kernel functions, but it's a good start. I defined the headers myself most of the time. You can also automatically generate them using [bindgen](https://crates.io/crates/bindgen).


# Closing words

It's great to see that so many people started to choose Rust for kernel drivers. I'll try to keep this document updated with the latest changes. 

Here's some great work by others, which might help you get started: 
- [rmccrystal/winkernel-rs](https://github.com/rmccrystal/winkernel-rs)
- [StephanvanSchaik/windows-kernel-rs](https://github.com/StephanvanSchaik/windows-kernel-rs)
- [mandiant/STrace](https://github.com/mandiant/STrace)
- [Windows Development](https://codentium.com/guides/windows-dev/)

Feel free to message me if I forgot to add something. Thanks for reading!

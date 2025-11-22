+++
title = "Pre-commit deleted all unstaged files"
date = "2025-11-22"

[taxonomies]
tags=["bug", "debugging", "git"]
+++

I was working on a new feature at $JOB and wanted to commit my changes from the last hour. I staged a few files, entered the commit message, committed them and waited for the pre-commit hooks to pass.

Unfortunately, the pre-commit hooks didn't pass because I had some style issues. And since I was using VSCode, I closed the dialog thinking that I just have to run `cargo fmt` once more. Then I realized that all my non-staged files were deleted.

# How to restore those files?

**Attempt 1: Git Stash/Reflog** - I didn't exactly know what `pre-commit` was doing, so I thought that maybe they are just stashing the unstaged files like you can do with the `git stash --keep-index` command. Unfortunately, I didn't find any new stash entries. Becoming a bit nervous, I also wanted to double check if there was a reflog entry for the deleted files. However, I couldn't find any reflog entries either.

**Attempt 2: VSCode File History** - There's a really useful command in VSCode called `Local History: Find Entry to Restore` which keeps track of all the file changes. This would have allowed me to restore all my files, but I was using [Zed](https://zed.dev) at the time which doesn't have this feature.

**Attempt 3: Claude Session**: I was using Claude to spec parts of the feature and do simple refactorings, so I was hoping it still had some of the file content in the conversation history. This approach worked, but it was mostly outdated and didn't contain all my lost files. Since I didn't want to rely on the CLI, I went into the `~/.claude` directory to search for parts of the content. There I discovered that its also storing a backup of each file in the `~/.claude/file-history` folder which you can search through. Unfortunately, this also only contained outdated content.

**Attempt 4: Pre-commit Cache**: After I finished restoring parts of my content with Claude, I wanted to commit the changes ASAP to not lose them again. This time, I was using the `git` CLI which failed again, losing all my changes...again. Luckily, this time I had the full logs of what went wrong.

```bash
$ git commit --amend --no-edit
[WARNING] Unstaged files detected.
[INFO] Stashing unstaged files to /home/not-matthias/.cache/pre-commit/patch1763743901-1677171.
trim trailing whitespace.................................................Passed
fix end of files.........................................................Passed
check yaml...........................................(no files to check)Skipped
check toml...............................................................Passed
check for added large files..............................................Passed
fmt..................................................(no files to check)Skipped
cargo check..........................................(no files to check)Skipped
clippy...............................................(no files to check)Skipped
[WARNING] Stashed changes conflicted with hook auto-fixes... Rolling back fixes...
An unexpected error has occurred: CalledProcessError: command: ('/nix/store/639k78iljhfmciklnivi0wja8jcy788g-git-2.50.1/libexec/git-core/git', '-c', 'core.autocrlf=false', 'apply', '--whitespace=nowarn', '/home/not-matthias/.cache/pre-commit/patch1763743901-1677171')
return code: 1
stdout: (none)
stderr:
    error: patch failed: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__perf_map__tests__ld_linux_symbols.snap:1
    error: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__perf_map__tests__ld_linux_symbols.snap: patch does not apply
    error: patch failed: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__cpp_unwind_data.snap:1
    error: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__cpp_unwind_data.snap: patch does not apply
    error: patch failed: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__golang_unwind_data.snap:1
    error: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__golang_unwind_data.snap: patch does not apply
    error: patch failed: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__ruff_unwind_data.snap:1
    error: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__ruff_unwind_data.snap: patch does not apply
    error: patch failed: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__rust_divan_unwind_data.snap:1
    error: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__rust_divan_unwind_data.snap: patch does not apply
    error: patch failed: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__the_algorithms_unwind_data.snap:1
    error: src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__the_algorithms_unwind_data.snap: patch does not apply
Check the log at /home/not-matthias/.cache/pre-commit/pre-commit.log
```

The most important line is this, which pointed me to the cache of pre-commit:

```
[INFO] Stashing unstaged files to /home/not-matthias/.cache/pre-commit/patch1763743901-1677171.
```

Looking at the file, I could see that this is just a git diff that was written to a file. We can restore it easily with the `patch` command:

```bash
$ patch -p1 < /home/not-matthias/.cache/pre-commit/patch1763742759-1588111
patching file crates/heaptrack/Cargo.toml
patching file crates/heaptrack/src/bpf.rs
patching file crates/heaptrack/src/events.rs
patching file crates/heaptrack/src/main.rs
...
patching file crates/runner-shared/src/lib.rs
patching file flake.nix
```

# Why did I fail?

I also managed to find the root cause of the `pre-commit` failure. For some reason, some test snapshots which should be stored in Git LFS weren't stored correctly. This even makes `git stash` fail:

```bash
$ git stash
Saved working directory and index state WIP on cod-1670-runner-profile-memory-of-command: bb882e9 fixup: runner-shared
Encountered 6 files that should have been pointers, but weren't:
        src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__perf_map__tests__ld_linux_symbols.snap
        src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__cpp_unwind_data.snap
        src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__golang_unwind_data.snap
        src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__ruff_unwind_data.snap
        src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__rust_divan_unwind_data.snap
        src/run/runner/wall_time/perf/snapshots/codspeed__run__runner__wall_time__perf__unwind_data__tests__the_algorithms_unwind_data.snap
```

To fix it, I had to run `git lfs migrate import --fixup` which resolved the issue. Then the `pre-commit` hook worked correctly again as well.

# Conclusion

I just wanted to write about this in case anyone else encounters the same issue. There are quite a few tricks to recover lost files nowadays, because many tools are copying them and storing them _somewhere_. For example, a colleague at work lost his ZSH history, but managed to recover it since he was using [Amazon Q](https://aws.amazon.com/q/) which sent his history to the cloud, but also kept a local copy.

So I guess it's time to thanks all the companies that collect and sell our data, as long as they store it locally so that we can use it for backups.

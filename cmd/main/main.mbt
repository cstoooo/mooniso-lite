///|
/// MoonISO Lite CLI entry point.
///
/// Milestone 1 intentionally keeps the command surface small:
/// `moon run cmd/main -- --help`.
fn main {
  let args = @env.args()
  let program = if args.length() > 0 { args[0] } else { "mooniso-lite" }
  if args.length() <= 1 || args[1] == "--help" || args[1] == "-h" {
    println("MoonISO Lite \{@mooniso.version()}")
    println("Usage: \{program} <pain.001.xml>")
    println("Status: project skeleton; pain.001 validation arrives in the next milestone.")
    return
  }
  println("MoonISO Lite skeleton is ready.")
  println("Next milestone will validate: \{args[1]}")
}

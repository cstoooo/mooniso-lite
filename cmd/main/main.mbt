///|
/// MoonISO Lite CLI entry point.
fn main {
  let args = @env.args()
  let program = if args.length() > 0 { args[0] } else { "mooniso-lite" }
  if args.length() <= 1 || args[1] == "--help" || args[1] == "-h" {
    println("MoonISO Lite \{@mooniso.version()}")
    println("Usage: \{program} <pain.001.xml>")
    println("Current command: summarize a pain.001 file.")
    return
  }
  let path = args[1]
  try {
    let xml = @fs.read_file_to_string(path)
    let summary = @mooniso.summarize_pain001(xml)
    println(summary.to_text())
  } catch {
    error => println("MoonISO Lite error: \{error}")
  }
}

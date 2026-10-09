///|
fn print_report(
  report : @mooniso.ValidationReport,
  format : String,
) -> Unit {
  match format {
    "json" => println(report.to_json())
    "markdown" | "md" => println(report.to_markdown())
    _ => println(report.to_text())
  }
}

///|
/// MoonISO Lite CLI entry point.
fn main {
  let args = @env.args()
  let program = if args.length() > 0 { args[0] } else { "mooniso-lite" }
  if args.length() <= 1 || args[1] == "--help" || args[1] == "-h" {
    println("MoonISO Lite \{@mooniso.version()}")
    println("Usage: \{program} [--format text|json|markdown] <pain.001.xml>")
    println("Current command: validate a pain.001 file.")
    return
  }
  let mut format = "text"
  let mut path : String? = None
  let mut i = 1
  while i < args.length() {
    if args[i] == "--format" && i + 1 < args.length() {
      format = args[i + 1]
      i += 2
    } else if args[i] == "--json" {
      format = "json"
      i += 1
    } else if args[i] == "--markdown" || args[i] == "--md" {
      format = "markdown"
      i += 1
    } else {
      path = Some(args[i])
      i += 1
    }
  }
  match path {
    None => println("Missing pain.001 XML path.")
    Some(file_path) =>
      try {
        let xml = @fs.read_file_to_string(file_path)
        let report = @mooniso.validate_pain001(xml)
        print_report(report, format)
      } catch {
        error => println("MoonISO Lite error: \{error}")
      }
  }
}

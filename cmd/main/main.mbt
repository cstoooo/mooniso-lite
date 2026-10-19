///|
fn print_validation(
  report : @mooniso.MessageValidation,
  format : String,
) -> Unit {
  match format {
    "json" => println(report.to_json())
    "markdown" | "md" => println(report.to_markdown())
    _ => println(report.to_text())
  }
}

///|
fn print_reconciliation(
  report : @mooniso.ReconciliationReport,
  format : String,
) -> Unit {
  match format {
    "json" => println(report.to_json())
    "markdown" | "md" => println(report.to_markdown())
    _ => println(report.to_text())
  }
}

///|
fn read_format_and_paths(
  args : Array[String],
  start_index : Int,
) -> (String, Array[String]) {
  let mut format = "text"
  let paths : Array[String] = []
  let mut i = start_index
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
      paths.push(args[i])
      i += 1
    }
  }
  (format, paths)
}

///|
/// MoonISO CLI entry point.
fn main {
  let args = @env.args()
  let program = if args.length() > 0 { args[0] } else { "mooniso-lite" }
  if args.length() <= 1 || args[1] == "--help" || args[1] == "-h" {
    println("MoonISO Lite \{@mooniso.version()}")
    println("Usage:")
    println("  \{program} [--format text|json|markdown] <message.xml>")
    println("  \{program} reconcile <pain.001.xml> <status.xml> [--format ...]")
    return
  }
  if args[1] == "--version" {
    println(@mooniso.version())
    return
  }
  if args[1] == "reconcile" {
    let (format, paths) = read_format_and_paths(args, 2)
    if paths.length() < 2 {
      println("reconcile requires a pain.001 file and a status report file.")
      return
    }
    try {
      let pain_xml = @fs.read_file_to_string(paths[0])
      let status_xml = @fs.read_file_to_string(paths[1])
      let report = @mooniso.reconcile_pain001_status(pain_xml, status_xml)
      print_reconciliation(report, format)
    } catch {
      @fs.IOError(message) => println("Cannot read input: \{message}")
      @mooniso.XmlParseError(message) => println("Invalid XML: \{message}")
      _ => println("MoonISO Lite error")
    }
    return
  }
  let (format, paths) = read_format_and_paths(args, 1)
  match paths {
    [] => println("Missing ISO 20022 XML path.")
    [file_path, ..] =>
      try {
        let xml = @fs.read_file_to_string(file_path)
        let report = @mooniso.validate_message(xml)
        print_validation(report, format)
      } catch {
        @fs.IOError(message) => println("Cannot read \{file_path}: \{message}")
        @mooniso.XmlParseError(message) => println("Invalid XML in \{file_path}: \{message}")
        _ => println("MoonISO Lite error")
      }
  }
}

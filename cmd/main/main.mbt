///|
fn print_validation(
  report : @moonpay.MessageValidation,
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
  report : @moonpay.ReconciliationReport,
  format : String,
) -> Unit {
  match format {
    "json" => println(report.to_json())
    "markdown" | "md" => println(report.to_markdown())
    _ => println(report.to_text())
  }
}

///|
fn print_lifecycle(
  report : @moonpay.LifecycleReport,
  format : String,
) -> Unit {
  match format {
    "json" => println(report.to_json())
    "markdown" | "md" => println(report.to_markdown())
    _ => println(report.to_text())
  }
}

///|
fn print_statement_audit(
  report : @moonpay.StatementAuditReport,
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
/// MoonPay Flow CLI entry point.
fn main {
  let args = @env.args()
  let program = if args.length() > 0 { args[0] } else { "moonpay-flow" }
  if args.length() <= 1 || args[1] == "--help" || args[1] == "-h" {
    println("MoonPay Flow \{@moonpay.version()}")
    println("Usage:")
    println("  \{program} [--format text|json|markdown] <message.xml>")
    println("  \{program} reconcile <pain.001.xml> <status.xml> [--format ...]")
    println("  \{program} lifecycle <pain.001.xml> <status.xml> <camt.053.xml> [--format ...]")
    println("  \{program} audit <camt.053.xml> [--format ...]")
    println("  \{program} --list-rules")
    return
  }
  if args[1] == "--version" {
    println(@moonpay.version())
    return
  }
  if args[1] == "--list-rules" {
    for rule in @moonpay.rule_catalog() {
      println(rule.code + " - " + rule.description)
    }
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
      let report = @moonpay.reconcile_pain001_status(pain_xml, status_xml)
      print_reconciliation(report, format)
    } catch {
      @fs.IOError(message) => println("Cannot read input: \{message}")
      @moonpay.XmlParseError(message) => println("Invalid XML: \{message}")
      _ => println("MoonPay Flow error")
    }
    return
  }
  if args[1] == "lifecycle" {
    let (format, paths) = read_format_and_paths(args, 2)
    if paths.length() < 3 {
      println("lifecycle requires pain.001, status and camt.053 files.")
      return
    }
    try {
      let pain_xml = @fs.read_file_to_string(paths[0])
      let status_xml = @fs.read_file_to_string(paths[1])
      let statement_xml = @fs.read_file_to_string(paths[2])
      let report = @moonpay.lifecycle_report(pain_xml, status_xml, statement_xml)
      print_lifecycle(report, format)
    } catch {
      @fs.IOError(message) => println("Cannot read input: \{message}")
      @moonpay.XmlParseError(message) => println("Invalid XML: \{message}")
      _ => println("MoonPay Flow error")
    }
    return
  }
  if args[1] == "audit" {
    let (format, paths) = read_format_and_paths(args, 2)
    if paths.length() < 1 {
      println("audit requires a camt.053 file.")
      return
    }
    try {
      let statement_xml = @fs.read_file_to_string(paths[0])
      let report = @moonpay.statement_audit(statement_xml)
      print_statement_audit(report, format)
    } catch {
      @fs.IOError(message) => println("Cannot read input: \{message}")
      @moonpay.XmlParseError(message) => println("Invalid XML: \{message}")
      _ => println("MoonPay Flow error")
    }
    return
  }
  let (format, paths) = read_format_and_paths(args, 1)
  match paths {
    [] => println("Missing ISO 20022 XML path.")
    [file_path, ..] =>
      try {
        let xml = @fs.read_file_to_string(file_path)
        let report = @moonpay.validate_message(xml)
        print_validation(report, format)
      } catch {
        @fs.IOError(message) => println("Cannot read \{file_path}: \{message}")
        @moonpay.XmlParseError(message) => println("Invalid XML in \{file_path}: \{message}")
        _ => println("MoonPay Flow error")
      }
  }
}

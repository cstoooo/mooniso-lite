///|
/// XML parsing error used by the project-local reader.
pub(all) suberror XmlParseError {
  XmlParseError(String)
}

///|
pub struct XmlElement {
  name : String
  attributes : Array[(String, String)]
}

///|
pub fn XmlElement::get(self : XmlElement, name : String) -> String? {
  for pair in self.attributes {
    if pair.0 == name {
      return Some(pair.1)
    }
  }
  None
}

///|
pub(all) enum EventKind {
  Start(XmlElement)
  Empty(XmlElement)
  Text(String)
  End(String)
  Eof
}

///|
pub struct Event {
  kind : EventKind
}

///|
pub struct XmlReader {
  input : Array[Char]
  mut pos : Int
  mut line : Int
  mut column : Int
  tag_stack : Array[String]
  mut saw_root : Bool
  mut root_closed : Bool
}

///|
fn is_xml_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

///|
fn is_name_char(c : Char) -> Bool {
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  is_digit(c) ||
  c == '_' ||
  c == ':' ||
  c == '-' ||
  c == '.'
}

///|
fn is_all_whitespace(text : String) -> Bool {
  for c in text {
    if !is_xml_whitespace(c) {
      return false
    }
  }
  true
}

///|
pub fn XmlReader::from_string(text : String) -> XmlReader {
  {
    input: text.to_array(),
    pos: 0,
    line: 1,
    column: 1,
    tag_stack: [],
    saw_root: false,
    root_closed: false,
  }
}

///|
fn XmlReader::peek(self : XmlReader) -> Char? {
  if self.pos < self.input.length() {
    Some(self.input[self.pos])
  } else {
    None
  }
}

///|
fn XmlReader::advance(self : XmlReader) -> Char? {
  if self.pos < self.input.length() {
    let c = self.input[self.pos]
    self.pos += 1
    if c == '\n' {
      self.line += 1
      self.column = 1
    } else {
      self.column += 1
    }
    Some(c)
  } else {
    None
  }
}

///|
fn XmlReader::skip_whitespace(self : XmlReader) -> Unit {
  while self.peek() is Some(c) && is_xml_whitespace(c) {
    let _ = self.advance()
  }
}

///|
fn XmlReader::check_string(self : XmlReader, text : String) -> Bool {
  let chars = text.to_array()
  if self.pos + chars.length() > self.input.length() {
    return false
  }
  for i = 0; i < chars.length(); i = i + 1 {
    if self.input[self.pos + i] != chars[i] {
      return false
    }
  }
  true
}

///|
fn XmlReader::skip_string(self : XmlReader, text : String) -> Bool {
  if !self.check_string(text) {
    return false
  }
  for i = 0; i < text.length(); i = i + 1 {
    let _ = self.advance()
  }
  true
}

///|
fn XmlReader::read_name(self : XmlReader) -> String raise XmlParseError {
  let buf = StringBuilder()
  while self.peek() is Some(c) && is_name_char(c) {
    buf.write_char(c)
    let _ = self.advance()
  }
  let name = buf.to_string()
  if name == "" {
    raise XmlParseError("expected XML name at line " + self.line.to_string())
  }
  name
}

///|
fn parse_entity_number(raw : String, start : Int, base : Int) -> Int? {
  if start >= raw.length() {
    return None
  }
  let mut value = 0
  for i = start; i < raw.length(); i = i + 1 {
    let c = raw[i].unsafe_to_char()
    let digit = if is_digit(c) {
      c.to_int() - '0'.to_int()
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 'a'.to_int() + 10
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    if digit >= base {
      return None
    }
    value = value * base + digit
  }
  Some(value)
}

///|
fn XmlReader::read_entity(self : XmlReader) -> String raise XmlParseError {
  let _ = self.advance()
  let buf = StringBuilder()
  while self.peek() is Some(c) && c != ';' {
    buf.write_char(c)
    let _ = self.advance()
  }
  match self.peek() {
    Some(';') => {
      let _ = self.advance()
    }
    _ => raise XmlParseError("unterminated entity at line " + self.line.to_string())
  }
  let raw = buf.to_string()
  match raw {
    "amp" => "&"
    "lt" => "<"
    "gt" => ">"
    "quot" => "\""
    "apos" => "'"
    _ =>
      if raw.length() > 0 && raw[0].unsafe_to_char() == '#' {
        let (start, base) = if raw.length() > 1 && raw[1].unsafe_to_char() == 'x' {
          (2, 16)
        } else {
          (1, 10)
        }
        match parse_entity_number(raw, start, base) {
          Some(code) => {
            let out = StringBuilder()
            out.write_char(code.unsafe_to_char())
            out.to_string()
          }
          None => raise XmlParseError("invalid numeric entity &" + raw + ";")
        }
      } else {
        raise XmlParseError("unknown entity &" + raw + ";")
      }
  }
}

///|
fn XmlReader::read_quoted_value(self : XmlReader) -> String raise XmlParseError {
  let quote = match self.advance() {
    Some(c) => c
    None => raise XmlParseError("expected quoted value")
  }
  if quote != '"' && quote != '\'' {
    raise XmlParseError("expected quoted value at line " + self.line.to_string())
  }
  let buf = StringBuilder()
  while self.peek() is Some(c) {
    if c == quote {
      let _ = self.advance()
      return buf.to_string()
    } else if c == '&' {
      buf.write_string(self.read_entity())
    } else {
      buf.write_char(c)
      let _ = self.advance()
    }
  }
  raise XmlParseError("unterminated attribute value at line " + self.line.to_string())
}

///|
fn XmlReader::read_text(self : XmlReader) -> String raise XmlParseError {
  let buf = StringBuilder()
  while self.peek() is Some(c) && c != '<' {
    if c == '&' {
      buf.write_string(self.read_entity())
    } else {
      buf.write_char(c)
      let _ = self.advance()
    }
  }
  buf.to_string()
}

///|
fn XmlReader::skip_until(self : XmlReader, marker : String, label : String) -> Unit raise XmlParseError {
  while !self.check_string(marker) {
    match self.advance() {
      Some(_) => ()
      None => raise XmlParseError("unterminated " + label + " at line " + self.line.to_string())
    }
  }
  let _ = self.skip_string(marker)
}

///|
fn XmlReader::read_markup(self : XmlReader) -> EventKind? raise XmlParseError {
  let _ = self.advance()
  match self.peek() {
    Some('?') => {
      self.skip_until("?>", "processing instruction")
      None
    }
    Some('!') => {
      if self.check_string("!--") {
        let _ = self.skip_string("!--")
        self.skip_until("-->", "comment")
        None
      } else if self.check_string("![CDATA[") {
        let _ = self.skip_string("![CDATA[")
        let buf = StringBuilder()
        while !self.check_string("]]>") {
          match self.advance() {
            Some(c) => buf.write_char(c)
            None => raise XmlParseError("unterminated CDATA at line " + self.line.to_string())
          }
        }
        let _ = self.skip_string("]]>")
        Some(Text(buf.to_string()))
      } else {
        self.skip_until(">", "declaration")
        None
      }
    }
    Some('/') => {
      let _ = self.advance()
      let name = self.read_name()
      self.skip_whitespace()
      match self.peek() {
        Some('>') => {
          let _ = self.advance()
        }
        _ => raise XmlParseError("expected > after closing tag at line " + self.line.to_string())
      }
      if self.tag_stack.length() == 0 {
        raise XmlParseError("unexpected closing tag </" + name + ">")
      }
      let expected = self.tag_stack[self.tag_stack.length() - 1]
      if expected != name {
        raise XmlParseError("closing tag </" + name + "> does not match <" + expected + ">")
      }
      let _ = self.tag_stack.remove(self.tag_stack.length() - 1)
      if self.tag_stack.length() == 0 {
        self.root_closed = true
      }
      Some(End(name))
    }
    Some(_) => {
      let name = self.read_name()
      let attributes : Array[(String, String)] = []
      let mut empty = false
      for ;; {
        self.skip_whitespace()
        match self.peek() {
          Some('>') => {
            let _ = self.advance()
            break
          }
          Some('/') => {
            let _ = self.advance()
            match self.peek() {
              Some('>') => {
                let _ = self.advance()
                empty = true
                break
              }
              _ => raise XmlParseError("expected /> at line " + self.line.to_string())
            }
          }
          Some(_) => {
            let attr_name = self.read_name()
            self.skip_whitespace()
            match self.advance() {
              Some('=') => ()
              _ => raise XmlParseError("expected = after attribute name")
            }
            self.skip_whitespace()
            let attr_value = self.read_quoted_value()
            attributes.push((attr_name, attr_value))
          }
          None => raise XmlParseError("unterminated start tag")
        }
      }
      let element = { name, attributes, }
      if empty {
        if self.tag_stack.length() == 0 {
          self.saw_root = true
          self.root_closed = true
        }
        Some(Empty(element))
      } else {
        if self.tag_stack.length() == 0 {
          self.saw_root = true
        }
        self.tag_stack.push(name)
        Some(Start(element))
      }
    }
    None => raise XmlParseError("unexpected end of input")
  }
}

///|
pub fn XmlReader::read_event(self : XmlReader) -> Event raise XmlParseError {
  for ;; {
    if self.pos >= self.input.length() {
      if self.tag_stack.length() > 0 {
        raise XmlParseError(
          "unclosed element <" + self.tag_stack[self.tag_stack.length() - 1] + ">",
        )
      }
      return { kind: Eof, }
    }
    if self.peek() is Some('<') {
      match self.read_markup() {
        Some(kind) => return { kind, }
        None => continue
      }
    } else {
      let text = self.read_text()
      if text == "" {
        continue
      }
      if !self.saw_root && is_all_whitespace(text) {
        continue
      }
      if self.root_closed && !is_all_whitespace(text) {
        raise XmlParseError("content after root element")
      }
      return { kind: Text(text), }
    }
  }
}

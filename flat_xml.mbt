///|
/// One element or text event with its full XML path.
pub struct XmlField {
  path : String
  attributes : Array[(String, String)]
  text : String?
}

///|
pub fn XmlField::get_attribute(self : XmlField, name : String) -> String? {
  for pair in self.attributes {
    if pair.0 == name {
      return Some(pair.1)
    }
  }
  None
}

///|
fn join_path(path : Array[String]) -> String {
  let output = StringBuilder()
  for i = 0; i < path.length(); i = i + 1 {
    if i > 0 {
      output.write_char('/')
    }
    output.write_string(path[i])
  }
  output.to_string()
}

///|
pub fn flatten_xml(xml_text : String) -> Array[XmlField] raise XmlParseError {
  let reader = XmlReader::from_string(xml_text)
  let path : Array[String] = []
  let fields : Array[XmlField] = []
  for ;; {
    match reader.read_event().kind {
      Start(element) => {
        path.push(element.name)
        fields.push({
          path: join_path(path),
          attributes: element.attributes,
          text: None,
        })
      }
      Empty(element) => {
        path.push(element.name)
        fields.push({
          path: join_path(path),
          attributes: element.attributes,
          text: None,
        })
        let _ = path.remove(path.length() - 1)
      }
      Text(content) => {
        fields.push({
          path: join_path(path),
          attributes: [],
          text: Some(content),
        })
      }
      End(_) => {
        if path.length() > 0 {
          let _ = path.remove(path.length() - 1)
        }
      }
      Eof => break
    }
  }
  fields
}

///|
pub fn first_text_by_suffix(
  fields : Array[XmlField],
  suffix : String,
) -> String? {
  for field in fields {
    if field.path.has_suffix(suffix) {
      match field.text {
        Some(text) =>
          if text != "" {
            return Some(text)
          }
        None => ()
      }
    }
  }
  None
}

///|
pub fn texts_by_suffix(fields : Array[XmlField], suffix : String) -> Array[String] {
  let values : Array[String] = []
  for field in fields {
    if field.path.has_suffix(suffix) {
      match field.text {
        Some(text) =>
          if text != "" {
            values.push(text)
          }
        None => ()
      }
    }
  }
  values
}

///|
pub fn fields_by_suffix(
  fields : Array[XmlField],
  suffix : String,
) -> Array[XmlField] {
  let values : Array[XmlField] = []
  for field in fields {
    if field.path.has_suffix(suffix) {
      values.push(field)
    }
  }
  values
}

///|
pub fn elements_by_suffix(
  fields : Array[XmlField],
  suffix : String,
) -> Array[XmlField] {
  let values : Array[XmlField] = []
  for field in fields {
    if field.path.has_suffix(suffix) && field.text is None {
      values.push(field)
    }
  }
  values
}

///|
/// Non-negative fixed-point decimal with a maximum scale of 2.
pub struct Decimal {
  minor_units : Int
  scale : Int
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
pub fn Decimal::zero() -> Decimal {
  { minor_units: 0, scale: 2, }
}

///|
pub fn Decimal::parse(value : String) -> Decimal? {
  if value == "" || value[0] == '.' || value[value.length() - 1] == '.' {
    return None
  }
  let mut units = 0
  let mut dot_count = 0
  let mut digit_count = 0
  let mut fraction_digits = 0
  let mut seen_dot = false
  for c in value {
    if is_digit(c) {
      digit_count += 1
      units = units * 10 + (c.to_int() - '0'.to_int())
      if seen_dot {
        fraction_digits += 1
      }
    } else if c == '.' {
      dot_count += 1
      seen_dot = true
    } else {
      return None
    }
  }
  if digit_count == 0 || dot_count > 1 || fraction_digits > 2 {
    return None
  }
  if fraction_digits == 0 {
    units = units * 100
  } else if fraction_digits == 1 {
    units = units * 10
  }
  Some({ minor_units: units, scale: 2, })
}

///|
pub fn Decimal::is_positive(self : Decimal) -> Bool {
  self.minor_units > 0
}

///|
pub fn Decimal::add(self : Decimal, other : Decimal) -> Decimal {
  { minor_units: self.minor_units + other.minor_units, scale: 2, }
}

///|
pub fn Decimal::subtract(self : Decimal, other : Decimal) -> Decimal {
  { minor_units: self.minor_units - other.minor_units, scale: 2, }
}

///|
pub fn Decimal::compare(self : Decimal, other : Decimal) -> Int {
  if self.minor_units < other.minor_units {
    -1
  } else if self.minor_units > other.minor_units {
    1
  } else {
    0
  }
}

///|
pub fn Decimal::to_string(self : Decimal) -> String {
  let negative = self.minor_units < 0
  let absolute = if negative { -self.minor_units } else { self.minor_units }
  let whole = absolute / 100
  let fraction = absolute % 100
  let fraction_text = if fraction < 10 {
    "0" + fraction.to_string()
  } else {
    fraction.to_string()
  }
  (if negative { "-" } else { "" }) + whole.to_string() + "." + fraction_text
}

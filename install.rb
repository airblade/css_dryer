# Print installation section of README.
readme = IO.read(File.join(File.dirname(__FILE__), 'README.markdown'))
puts readme[/(## Installation.*?)##/m, 1]

# Require the necessary standard libraries
require 'rexml/document'

# Load the JRuby Open SSL library unless it has already been loaded.  This
# prevents multiple handlers using the same library from causing problems.
if not defined?(Jopenssl)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, 'vendor/jruby-openssl-0.6/lib')
  $:.unshift library_path
  # Require the library
  require 'openssl'
  # Require the version constant
  require 'jopenssl/version'
end

# Validate the the loaded openssl library is the library that is expected for
# this handler to execute properly.
if not defined?(Jopenssl::Version::VERSION)
  raise "The Jopenssl class does not define the expected VERSION constant."
elsif Jopenssl::Version::VERSION != '0.6'
  raise "Incompatible library version #{Jopenssl::Version::VERSION} for Jopenssl.  Expecting version 0.6."
end

# Load the Amazon Web Services library unless it has already been loaded.  This
# prevents multiple handlers using the same library from causing problems.
if not defined?(AWS)
  # Calculate the location of this file
  handler_path = File.expand_path(File.dirname(__FILE__))
  # Calculate the location of our library and add it to the Ruby load path
  library_path = File.join(handler_path, 'vendor/amazon-ec2-0.9.17/lib')
  $:.unshift library_path
  # Require the library
  require 'AWS'
end

# Validate the the loaded AWS library is the library that is expected for
# this handler to execute properly.
if not defined?(AWS::VERSION)
  raise "The AWS gem does not define the expected VERSION constant."
elsif AWS::VERSION != '0.9.17'
  raise "Incompatible library version #{AWS::VERSION} for AWS.  Expecting version 0.9.17."
end

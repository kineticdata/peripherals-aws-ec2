# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2InstanceStopV1
  # Prepare for execution by building Hash objects for necessary data and
  # configuration values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_doc - A REXML::Document object that represents the input XML.
  # * @access_key_id -  An info value used for AWS authentication.
  # * @secret_access_key - An info value used for AWS authentication.
  # * @ec2 - The AWS::EC2::Base object this handler uses to make API calls.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of XML that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text
    }

    # Retrieve all of the handler parameters and store them in a hash attribute
    # named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, 'handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s
    end

    @enable_debug_logging = @info_values['enable_debug_logging'].downcase == 'yes' ||
                            @info_values['enable_debug_logging'].downcase == 'true'
    puts "Parameters: #{@parameters.inspect}" if @enable_debug_logging

    # Retrieve the credentials for the AWS session from the input XML string
    creds = Aws::Credentials.new(@info_values['access_key'], @info_values['secret_key'])

    # Create a base AWS object. This object contains all the methods for accessing
    # Amazon Web Services
    @ec2 = Aws::EC2::Client.new(
      region: @info_values['region'],
      credentials: creds
    )

  end

  # This method essentially uses the stop_instances method provided by the
  # AWS::EC2::Base class to send a stop request to the specified instance.  The
  # request id of the stop request, the previous status of the instance, and the
  # current status of the instance are returned by this handler.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An XML formatted String representing the return variable results.
  def execute()
    instance_id = @parameters['instance_id']
    puts "Attempting to stop the instance '#{instance_id}'" if @enable_debug_logging
    # Execute the stop_instance. This will return a request id which can be used
    # with AWS technical support to trace issues.
    hres = @ec2.stop_instances("instance_ids": [instance_id])
    puts "Stop instance request response:\n  #{hres}" if @enable_debug_logging

    # We will set the returned values into intermediate variables to improve readability
    # of the results

    previous_status = hres.stopping_instances[0].previous_state.name
    current_status = hres.stopping_instances[0].current_state.name
    # Build the results XML that will be returned by this handler.
    puts "previous_status: #{previous_status}" if @enable_debug_logging
    puts "current_status: #{current_status}" if @enable_debug_logging
    <<-RESULTS
    <results>
        <result name="Previous Status">#{escape(previous_status)}</result>
        <result name="Current Status">#{escape(current_status)}</result>
    </results>
    RESULTS
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

end

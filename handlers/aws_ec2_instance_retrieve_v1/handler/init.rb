# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2InstanceRetrieveV1
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

  def execute()
    instance = @ec2.describe_instances(:instance_id => @instance_id).reservations[0].instances[0]
    puts "#{instance}" if @enable_debug_logging

    # Retrieve the specific machine properties.
    virtual_type = instance.virtualization_type
    ip_address = instance.public_ip_address
    kernel_id = instance.kernel_id
    private_ip_address = instance.private_ip_address
    key_name = instance.key_name
    launch_time = instance.launch_time
    instance_type = instance.instance_type
    image_id = instance.image_id
    ami_index = instance.ami_launch_index
    private_dns = instance.private_dns_name
    root_device_name = instance.root_device_name
    root_device_type = instance.root_device_type
    architecture = instance.architecture
    monitoring_state = instance.monitoring.state
    availability_zone = instance.placement.availability_zone
    public_dns = instance.public_dns_name
    instance_state = instance.state.name

    # Build the results XML that will be returned by this handler.
    <<-RESULTS
    <results>
        <result name="Virtualization Type">#{escape(virtual_type)}</result>
        <result name="IP Address">#{escape(ip_address)}</result>
        <result name="Kernel ID">#{escape(kernel_id)}</result>
        <result name="AMI Launcher Index">#{escape(ami_index)}</result>
        <result name="Private IP Address">#{escape(private_ip_address)}</result>
        <result name="Key Name">#{escape(key_name)}</result>
        <result name="Launch Time">#{escape(launch_time)}</result>
        <result name="Instance Type">#{escape(instance_type)}</result>
        <result name="Image ID">#{escape(image_id)}</result>
        <result name="Private DNS Name">#{escape(private_dns)}</result>
        <result name="Root Device Name">#{escape(root_device_name)}</result>
        <result name="Root Device Type">#{escape(root_device_type)}</result>
        <result name="Architecture">#{escape(architecture)}</result>
        <result name="Monitoring State">#{escape(monitoring_state)}</result>
        <result name="Availability Zone">#{escape(availability_zone)}</result>
        <result name="DNS Name">#{escape(public_dns)}</result>
        <result name="Instance State">#{escape(instance_state)}</result>
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

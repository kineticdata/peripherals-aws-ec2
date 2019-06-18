require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2CreateSubnetV1

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
    puts "Attempting to create the subnet" if @enable_debug_logging
    resp = @ec2.create_subnet(
      dry_run: @parameters['dry_run'],
      vpc_id: @parameters['vpc_id'],
      cidr_block: @parameters['cidr_block'],
      availability_zone: @parameters['availability_zone']
    )

    puts "Subnet succesfully created with the id '#{resp.subnet.subnet_id}'" if @enable_debug_logging
    <<-RESULTS
    <results>
      <result name="Subnet Id">#{escape(resp.subnet.subnet_id)}</result>
      <result name="Subnet State">#{escape(resp.subnet.state)}</result>
      <result name="Subnet VPC Id">#{escape(resp.subnet.vpc_id)}</result>
      <result name="Subnet CIDR Block">#{escape(resp.subnet.cidr_block)}</result>
      <result name="Subnet Available IP Address Count">#{escape(resp.subnet.available_ip_address_count)}</result>
      <result name="Subnet Availability Zone">#{escape(resp.subnet.availability_zone)}</result>
      <result name="Subnet Default for AZ">#{escape(resp.subnet.default_for_az)}</result>
      <result name="Subnet Map Public IP on Launch">#{escape(resp.subnet.map_public_ip_on_launch)}</result>
      <result name="Subnet Tags">#{escape(resp.subnet.tags.to_s)}</result>
    </results>
    RESULTS
  end

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

require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2AuthorizeSecurityGroupIngressV1

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
    # Validate the inputs
    if (
        (
          !@parameters['source_security_group_name'].to_s.empty? ||
          !@parameters['source_security_group_owner_id'].to_s.empty?
        )
        &&
        (
          !@parameters["cidr_ip"].to_s.empty? ||
          !@parameters["from_port"].to_s.empty? ||
          !@parameters["to_port"].to_s.empty? ||
          !@parameters["ip_protocol"].to_s.empty?
        )
    )
      raise "If a 'Source Security Group Name' or 'Source Security Group Owner Id' are specified,"+
      " the following parameters are not allowed to be set - 'CIDR IP','From Port','To Port','IP Protocol'"
    end

    # Build up the inputs
    inputs = {}
    inputs[:dry_run] = @parameters['dry_run']
    ['cidr_ip','from_port','to_port','ip_protocol','source_security_group_name',
    'source_security_group_owner_id','group_id','group_name'].each do |field|
      inputs[:"#{field}"] = @parameters[field] if !@parameters[field].to_s.empty?
    end

    puts "Attempting to apply the security ingress rule" if @enable_debug_logging

    resp = @ec2.authorize_security_group_ingress(inputs)

    puts "Security group ingress rule successfully applied." if @enable_debug_logging
    return "<results />"
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

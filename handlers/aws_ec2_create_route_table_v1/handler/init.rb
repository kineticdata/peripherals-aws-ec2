require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2CreateRouteTableV1

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

    resp = @ec2.create_route_table(
      dry_run: @parameters['dry_run'],
      vpc_id: @parameters['vpc_id']
    )

    puts resp.route_table if @enable_debug_logging

    <<-RESULTS
    <results>
      <result name="Route Table ID">#{escape(resp.route_table.route_table_id)}</result>
      <result name="Route Table VPC ID">#{escape(resp.route_table.vpc_id)}</result>
      <result name="Route Table Routes">#{escape(resp.route_table.routes.to_s)}</result>
      <result name="Route Table Associations">#{escape(resp.route_table.associations.to_s)}</result>
      <result name="Route Table Tag">#{escape(resp.route_table.tags.to_s)}</result>
      <result name="Route Table Propagation VGWS">#{escape(resp.route_table.propagating_vgws)}</result>
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

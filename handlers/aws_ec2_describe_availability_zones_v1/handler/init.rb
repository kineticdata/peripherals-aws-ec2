require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2DescribeAvailabilityZonesV1

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
    puts "Formatting the parameter inputs to conform to the expected AWS inputs" if @enable_debug_logging
    zone_names_array = []
    @parameters['zone_names'].split(",").each {|zone|
      zone_names_array.push(zone.strip)
    }

    puts "Attempting to retrieve the availability zones" if @enable_debug_logging
    if zone_names_array.length > 0
      resp = @ec2.describe_availability_zones(
        dry_run: @parameters['dry_run'],
        zone_names: zone_names_array
      )
    else
      resp = @ec2.describe_availability_zones(
        dry_run: @parameters['dry_run']
      )
    end
    puts "#{resp.availability_zones.size} availability zones successfully retrieved" if @enable_debug_logging

    zones_info = {}
    resp.availability_zones.each do |zone|
      messages = []
      zone["messages"].each { |m| messages.push(m["message"])}
      zones_info[zone["zone_name"]] = {
        "name" => zone["zone_name"],
        "state" => zone["state"],
        "region_name" => zone["region_name"],
        "messages" => messages
      }
    end

    return <<-RESULTS
    <results>
      <result name="Availability Zone Names">#{escape(zones_info.keys.join(','))}</result>
      <result name="Availability Zone Details">#{escape(zones_info.to_json)}</result>
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

require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2DescribeImagesV1

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

    inputs={}
    inputs[:dry_run] = @parameters['dry_run']

    image_id_array = []
    @parameters['image_ids'].split(",").each { |image_id|
      image_id_array.push(image_id.strip)
    }
    # populate the inputs with image_ids if any were submitted
    inputs[:image_ids] = image_id_array if image_id_array.length > 0

    owners_array = []
    @parameters['owners'].split(",").each { |owner|
      owners_array.push(owner.strip)
    }
    # populate the inputs with owners if any were submitted
    inputs[:owners] = owners_array if owners_array.length > 0

    executable_users_array = []
    @parameters['executable_users'].split(",").each { |executable_user|
      executable_users_array.push(executable_user.strip)
    }
    # populate the inputs with owners if any were submitted
    inputs[:executable_users] = executable_users_array if executable_users_array.length > 0

    filters_array = []
    if @parameters['filters'].strip != ""
      begin
        filters_json = JSON.parse(@parameters['filters'])
      rescue Exception => e
        raise "Error parsing filters input: #{@parameters['filters']}. \n#{e.message}"
      end

      filters_json.each{|key,value|
        filter_obj={}
        filter_obj[:name]=key
        filter_obj[:values]=value
        filters_array.push(filter_obj)
      }
    end
    # populate the inputs with owners if any were submitted
    inputs[:filters] = filters_array if filters_array.length > 0

    puts "Attempting to find images with the following search parameters: #{inputs}" if @enable_debug_logging
    resp = @ec2.describe_images(inputs)

    puts "The describe images call found the following images" if @enable_debug_logging
    puts resp.images if @enable_debug_logging

    images_id_array=[]
    resp.images.each{|image|
      images_id_array.push(image.image_id)
    }

    #availability_zone_xml = "<zones>\n"
    #resp.availability_zones.each do |zone|
    #  availability_zone_xml << "<zone name='#{zone['zone_name']}''>\n"
    #    availability_zone_xml << "<zone_name>" << zone['zone_name'] << "</zone_name>\n"
    #    availability_zone_xml << "<state>" << zone['state'] << "</state>\n"
    #    availability_zone_xml << "<region_name>" << zone['region_name'] << "</region_name>\n"
    #    availability_zone_xml << "<messages>\n"
    #    zone['messages'].each do |message|
    #      availability_zone_xml << "<message>" << message['message'] << "</message>\n"
    #    end
    #    availability_zone_xml << "</messages>\n"
    #  availability_zone_xml << "</zone>\n"
    #end
    #availability_zone_xml << "</zones>"

    #puts "Availability Zone XML" if @enable_debug_logging
    #puts availability_zone_xml if @enable_debug_logging

    return_xml = "<results>\n"
    return_xml += "<result name='Image Info String'>#{escape(resp.images.inspect)}</result>\n"
    return_xml += "<result name='Images Images ID String'>#{escape(images_id_array.to_s)}</result>\n"

    #resp.availability_zones.each do |zone_info|
    #  return_xml += "<result name='#{escape(zone_info['zone_name'])}'>#{escape(zone_info['zone_name'])}</result>\n"
    #end

    return_xml += "</results>"

    return return_xml

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

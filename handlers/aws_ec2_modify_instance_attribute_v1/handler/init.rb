require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2ModifyInstanceAttributeV1

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

    changed_attribute = {}
    @parameters.each do |x,y|
      if x != "dry_run" && x != "instance_id" && x != "value" && x != "attribute" && y.strip != ""
        changed_attribute['attribute_name'] = x
        changed_attribute['attribute_value'] = y
      end
      if x == "attribute" && @parameters['value'].strip != ""
        changed_attribute['attribute_name'] = y
        changed_attribute['attribute_value'] = @parameters['value']
      end
    end

    inputs={}
    inputs[:dry_run] = @parameters['dry_run']
    inputs[:instance_id] = @parameters['instance_id']
    inputs[:attribute] = @parameters['attribute'] if @parameters['attribute'].strip != ""
    inputs[:value] = @parameters['value'] if @parameters['value'].strip != ""
    inputs[:instance_type] = @parameters['instance_type'] if @parameters['instance_type'].strip!=""
    inputs[:kernel] = @parameters['kernel'] if @parameters['kernel'].strip!=""
    inputs[:ramdisk] = @parameters['ramdisk'] if @parameters['ramdisk'].strip!=""
    inputs[:instance_initiated_shutdown_behavior] = @parameters['instance_initiated_shutdown_behavior'] if @parameters['instance_initiated_shutdown_behavior'].strip!=""

    inputs[:source_dest_check] = { "value" => @parameters['source_dest_check']} if @parameters['source_dest_check'].strip!=""
    inputs[:disable_api_termination] = { "value" => @parameters['disable_api_termination']} if @parameters['disable_api_termination'].strip!=""
    inputs[:user_data] = { "value" => @parameters['user_data']} if @parameters['user_data'].strip!=""
    inputs[:ebs_optimized] = { "value" => @parameters['ebs_optimized']} if @parameters['ebs_optimized'].strip!=""

    security_group_ids_array = []
    @parameters['groups'].split(",").each { |group|
      security_group_ids_array.push(group.strip)
    }
    # populate the inputs with groups if any were submitted
    inputs[:groups] = security_group_ids_array if security_group_ids_array.length > 0

    block_device_mapping_array = []
    if @parameters['block_device_mappings'].strip != ""
      begin
        block_device_mapping_array = JSON.parse(@parameters['block_device_mappings'])
      rescue Exception => e
        raise "Error parsing block_device_mappings structure: #{@parameters['block_device_mappings']} \n\n#{e.message}"
      end
    end
    # populate the inputs with block device mappings if any were submitted
    inputs[:block_device_mappings] = block_device_mapping_array if block_device_mapping_array.length > 0

    puts "Updating the instance attributes with the following values: #{inputs}" if @enable_debug_logging

    resp = @ec2.modify_instance_attribute(inputs)

    puts "Instance attribute #{changed_attribute['attribute_name']} modified successfully to #{changed_attribute['attribute_value']}." if @enable_debug_logging

    <<-RESULTS
    <results/>
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

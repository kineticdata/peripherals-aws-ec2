require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2CreateNetworkInterfaceV1

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
    puts "Reformatting the input parameters to the format that the EC2 call expects" if @enable_debug_logging
    inputs={}
    inputs[:dry_run] = @parameters['dry_run']
    inputs[:subnet_id] = @parameters['subnet_id']
    inputs[:description] = @parameters['description']
    inputs[:private_ip_address] = @parameters['private_ip_address'] if @parameters['private_ip_address'].strip!=""
    inputs[:secondary_private_ip_address_count] = @parameters['secondary_private_ip_address_count'].to_i if @parameters['secondary_private_ip_address_count'].strip!=""

    # Split the groups csv, strip the whitespace from each element, and then
    # load it into a ruby array
    groups_array = []
    @parameters['groups'].split(",").each { |group|
      groups_array.push(group.strip)
    }
    # populate the inputs with groups if any were submitted
    inputs[:groups] = groups_array if groups_array.length > 0

    pipaddr_array = []
    if @parameters['private_ip_addresses'].strip != ""
      begin
        pipaddr_json = JSON.parse(@parameters['private_ip_addresses'])
      rescue Exception => e
        raise "Error parsing private_ip_addresses structure: #{@parameters['private_ip_addresses']} \n\n#{e.message}"
      end
    end
    # populate the inputs with owners if any were submitted
    inputs[:private_ip_addresses] = pipaddr_array if pipaddr_array.length > 0

    puts "Formatted Input Body: #{inputs.to_json}" if @enable_debug_logging

    resp = @ec2.create_network_interface(inputs)

    puts "Network Interface successfully created: \n  #{resp.network_interface}" if @enable_debug_logging

    # Initalize a hash for both the attachment details and association details,
    # so even if the attachment and association variables are null, their sub
    # properties (attachment_id, instance_id, etc.) instead return as null
    # instead of null pointer exceptions
    puts "Building up the results XML" if @enable_debug_logging
    attachment_details = {}
    if !resp.network_interface.attachment.nil?
      attachment_details['attachment_id'] = resp.network_interface.attachment.attachment_id
      attachment_details['instance_id'] = resp.network_interface.attachment.instance_id
      attachment_details['instance_owner_id'] = resp.network_interface.attachment.instance_owner_id
      attachment_details['device_index'] = resp.network_interface.attachment.device_index
      attachment_details['status'] = resp.network_interface.attachment.status
      attachment_details['attach_time'] = resp.network_interface.attachment.attach_time.strftime("%Y-%m-%dT%e:%M:%S%z")
      attachment_details['delete_on_termination'] = resp.network_interface.attachment.delete_on_termination
    end

    association_details = {}
    if !resp.network_interface.association.nil?
      attachment['public_ip'] = resp.network_interface.association.public_ip
      attachment['public_dns_name'] = resp.network_interface.association.public_dns_name
      attachment['ip_owner_id'] = resp.network_interface.association.ip_owner_id
      attachment['allocation_id'] = resp.network_interface.association.allocation_id
      attachment['association_id'] = resp.network_interface.association.association_id
    end

    <<-RESULTS
    <results>
      <result name="Network Interface Id">#{escape(resp.network_interface.network_interface_id)}</result>
      <result name="Subnet Id">#{escape(resp.network_interface.subnet_id)}</result>
      <result name="VPC Id">#{escape(resp.network_interface.vpc_id)}</result>
      <result name="Availability Zone">#{escape(resp.network_interface.availability_zone)}</result>
      <result name="Description">#{escape(resp.network_interface.description)}</result>
      <result name="Owner Id">#{escape(resp.network_interface.owner_id)}</result>
      <result name="Requester Id">#{escape(resp.network_interface.requester_id)}</result>
      <result name="Requester Managed">#{escape(resp.network_interface.requester_managed)}</result>
      <result name="Status">#{escape(resp.network_interface.status)}</result>
      <result name="MAC Address">#{escape(resp.network_interface.mac_address)}</result>
      <result name="Private IP Address">#{escape(resp.network_interface.private_ip_address)}</result>
      <result name="Private DNS Name">#{escape(resp.network_interface.private_dns_name)}</result>
      <result name="Source Dest Check">#{escape(resp.network_interface.source_dest_check)}</result>
      <result name="Groups">#{escape(resp.network_interface.groups.to_s)}</result>

      <result name="Attachment Attachment Id">#{escape(attachment_details["attachment_id"])}</result>
      <result name="Attachment Instance Id">#{escape(attachment_details["instance_id"])}</result>
      <result name="Attachment Instance Owner Id">#{escape(attachment_details["instance_owner_id"])}</result>
      <result name="Attachment Device Index">#{escape(attachment_details["device_index"])}</result>
      <result name="Attachment Status">#{escape(attachment_details["status"])}</result>
      <result name="Attachment Attach Time">#{escape(attachment_details["attach_time"])}</result>
      <result name="Attachment Delete On Termination">#{escape(attachment_details["delete_on_termination"])}</result>

      <result name="Association Public IP">#{escape(association_details["public_ip"])}</result>
      <result name="Association Public DNS Name">#{escape(association_details["public_dns_name"])}</result>
      <result name="Association IP Owner Id">#{escape(association_details["ip_owner_id"])}</result>
      <result name="Association Allocation Id">#{escape(association_details["allocation_id"])}</result>
      <result name="Association Association Id">#{escape(association_details["association_id"])}</result>

      <result name="Tag Set">#{escape(resp.network_interface.tag_set.to_s)}</result>
      <result name="Private IP Addresses">#{escape(resp.network_interface.private_ip_addresses.to_s)}</result>
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

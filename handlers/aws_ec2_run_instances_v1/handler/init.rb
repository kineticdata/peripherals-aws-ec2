require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2RunInstancesV1

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
    inputs[:image_id] = @parameters['image_id']
    inputs[:min_count] = @parameters['min_count'].to_i
    inputs[:max_count] = @parameters['max_count'].to_i
    inputs[:monitoring] = {:enabled => @parameters['monitoring']}
    inputs[:key_name] = @parameters['key_name'] if @parameters['key_name'].strip!=""
    inputs[:user_data] = @parameters['user_data'] if @parameters['user_data'].strip!=""
    inputs[:instance_type] = @parameters['instance_type'] if @parameters['instance_type'].strip!=""
    inputs[:kernel_id] = @parameters['kernel_id'] if @parameters['kernel_id'].strip!=""
    inputs[:ramdisk_id] = @parameters['ramdisk_id'] if @parameters['ramdisk_id'].strip!=""
    inputs[:subnet_id] = @parameters['subnet_id'] if @parameters['subnet_id'].strip!=""
    inputs[:disable_api_termination] = @parameters['disable_api_termination'] if @parameters['disable_api_termination'].strip!=""
    inputs[:instance_initiated_shutdown_behavior] = @parameters['instance_initiated_shutdown_behavior'] if @parameters['instance_initiated_shutdown_behavior'].strip!=""
    inputs[:private_ip_address] = @parameters['private_ip_address'] if @parameters['private_ip_address'].strip!=""
    inputs[:client_token] = @parameters['client_token']
    inputs[:ebs_optimized] = @parameters['ebs_optimized'] if @parameters['ebs_optimized'].strip!=""

    security_groups_array = []
    @parameters['security_groups'].split(",").each { |group|
      security_groups_array.push(group.strip)
    }
    # populate the inputs with groups if any were submitted
    inputs[:security_groups] = security_groups_array if security_groups_array.length > 0

    security_group_ids_array = []
    @parameters['security_group_ids'].split(",").each { |group|
      security_group_ids_array.push(group.strip)
    }
    # populate the inputs with groups if any were submitted
    inputs[:security_group_ids] = security_group_ids_array if security_group_ids_array.length > 0

    placement_hash = {}
    if @parameters['placement'].strip != ""
      begin
        placement_hash = JSON.parse(@parameters['placement'])
      rescue Exception => e
        raise "Error parsing placement structure: #{@parameters['placement']} \n\n#{e.message}"
      end
    end
    # populate the inputs with placements if any were submitted
    inputs[:placement] = placement_hash if placement_hash.length > 0

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

    network_interfaces_array = []
    if @parameters['network_interfaces'].strip != ""
      begin
        network_interfaces_array = JSON.parse(@parameters['network_interfaces'])
      rescue Exception => e
        raise "Error parsing network interfaces structure: #{@parameters['network_interfaces']} \n\n#{e.message}"
      end
    end
    # populate the inputs with network interfaces if any were submitted
    inputs[:network_interfaces] = network_interfaces_array if network_interfaces_array.length > 0

    iam_instance_profiles_hash = {}
    if @parameters['iam_instance_profile'].strip != ""
      begin
        iam_instance_profiles_hash = JSON.parse(@parameters['iam_instance_profile'])
      rescue Exception => e
        raise "Error parsing network interfaces structure: #{@parameters['iam_instance_profile']} \n\n#{e.message}"
      end
    end
    # populate the inputs with network interfaces if any were submitted
    inputs[:iam_instance_profile] = iam_instance_profiles_hash if iam_instance_profiles_hash.length > 0

    puts inputs if @enable_debug_logging

    resp = @ec2.run_instances(inputs)

    puts resp.reservation_id if @enable_debug_logging
    puts resp.owner_id if @enable_debug_logging
    puts resp.requester_id if @enable_debug_logging
    puts resp.groups.to_s if @enable_debug_logging
    puts resp.instances.to_s if @enable_debug_logging

    groups_xml = "<groups>\n"
    resp.groups.each do |group|
      groups_xml = "<group>\n"
      groups_xml += "<group_name>#{escape(group.group_name)}</group_name>\n"
      groups_xml += "<group_id>#{escape(group.group_id)}</group_id>\n"
      groups_xml = "</group>\n"
    end
    groups_xml += "</groups>"

    puts groups_xml if @enable_debug_logging

    instances_xml = "<instances>\n"
    resp.instances.each do |instance|
      instances_xml += "<instance>\n"
      instances_xml += "<instance_id>#{escape(instance.instance_id)}</instance_id>\n"
      instances_xml += "<image_id>#{escape(instance.image_id)}</image_id>\n"
      instances_xml += "<state_code>#{escape(instance.state.code)}</state_code>\n"
      instances_xml += "<state_name>#{escape(instance.state.name)}</state_name>\n"
      instances_xml += "<private_dns_name>#{escape(instance.private_dns_name)}</private_dns_name>\n"
      instances_xml += "<state_transition_reason>#{escape(instance.state_transition_reason)}</state_transition_reason>\n"
      instances_xml += "<key_name>#{escape(instance.key_name)}</key_name>\n"
      instances_xml += "<ami_launch_index>#{escape(instance.ami_launch_index)}</ami_launch_index>\n"
      instances_xml += "<product_codes>\n"
      instance.product_codes.each do |code|
        instances_xml += "<product_code>\n"
        instances_xml += "<product_code_id>#{escape(code.product_code_id)}</product_code_id>\n"
        instances_xml += "<product_code_type>#{escape(code.product_code_type)}</product_code_type>\n"
        instances_xml += "</product_code>\n"
      end
      instances_xml += "</product_codes>\n"
      instances_xml += "<instance_type>#{escape(instance.instance_type)}</instance_type>\n"
      instances_xml += "<launch_time>#{escape(instance.launch_time)}</launch_time>\n"
      instances_xml += "<placement_availability_zone>#{escape(instance.placement.availability_zone)}</placement_availability_zone>\n"
      instances_xml += "<placement_group_name>#{escape(instance.placement.group_name)}</placement_group_name>\n"
      instances_xml += "<placement_tenancy>#{escape(instance.placement.tenancy)}</placement_tenancy>\n"
      instances_xml += "<kernel_id>#{escape(instance.kernel_id)}</kernel_id>\n"
      instances_xml += "<ramdisk_id>#{escape(instance.ramdisk_id)}</ramdisk_id>\n"
      instances_xml += "<platform>#{escape(instance.platform)}</platform>\n"
      instances_xml += "<monitoring_state>#{escape(instance.monitoring.state)}</monitoring_state>\n"
      instances_xml += "<subnet_id>#{escape(instance.subnet_id)}</subnet_id>\n"
      instances_xml += "<vpc_id>#{escape(instance.vpc_id)}</vpc_id>\n"
      instances_xml += "<private_ip_address>#{escape(instance.private_ip_address)}</private_ip_address>\n"
      instances_xml += "<public_ip_address>#{escape(instance.public_ip_address)}</public_ip_address>\n"
      instances_xml += "<state_reason_code>#{escape(instance.state_reason.code)}</state_reason_code>\n"
      instances_xml += "<state_reason_message>#{escape(instance.state_reason.message)}</state_reason_message>\n"
      instances_xml += "<architecture>#{escape(instance.architecture)}</architecture>\n"
      instances_xml += "<root_device_type>#{escape(instance.root_device_type)}</root_device_type>\n"
      instances_xml += "<root_device_name>#{escape(instance.root_device_name)}</root_device_name>\n"
      instances_xml += "<block_device_mappings>\n"
      instance.block_device_mappings.each do |mapping|
        instances_xml += "<block_device_mapping>\n"
        instances_xml += "<device_name>#{escape(mapping.device_name)}</device_name>\n"
        instances_xml += "<ebs_volume_id>#{escape(mapping.ebs.volume_id)}</ebs_volume_id>\n"
        instances_xml += "<ebs_status>#{escape(mapping.ebs.status)}</ebs_status>\n"
        instances_xml += "<ebs_attach_time>#{escape(mapping.ebs.attach_time.strftime("%Y-%m-%dT%e:%M:%S%z"))}</ebs_attach_time>\n"
        instances_xml += "<ebs_delete_on_termination>#{escape(mapping.ebs.delete_on_termination)}</ebs_delete_on_termination>\n"
        instances_xml += "</block_device_mapping>\n"
      end
      instances_xml += "</block_device_mappings>\n"
      instances_xml += "<virtualization_type>#{escape(instance.virtualization_type)}</virtualization_type>\n"
      instances_xml += "<instance_lifecycle>#{escape(instance.instance_lifecycle)}</instance_lifecycle>\n"
      instances_xml += "<spot_instance_request_id>#{escape(instance.spot_instance_request_id)}</spot_instance_request_id>\n"
      instances_xml += "<client_token>#{escape(instance.client_token)}</client_token>\n"
      instances_xml += "<tags>\n"
      instance.tags.each do |tag|
        instances_xml += "<tag>\n"
        instances_xml += "<tagvalue name='#{tag.key}'>#{escape(tag.value)}</tag>\n"
        instances_xml += "<key>#{escape(tag.key)}</key>\n"
        instances_xml += "<value>#{escape(tag.value)}</value>\n"
        instances_xml += "</tag>\n"
      end
      instances_xml += "</tags>\n"
      instances_xml += "<security_groups>\n"
      instance.security_groups.each do |group|
        instances_xml += "<security_group>\n"
        instances_xml += "<group name='#{group.group_name}'>#{escape(group.group_id)}</group>\n"
        instances_xml += "<group_name>#{escape(group.group_name)}</group_name>\n"
        instances_xml += "<group_id>#{escape(group.group_id)}</group_id>\n"
        instances_xml += "</security_group>\n"
      end
      instances_xml += "</security_groups>\n"
      instances_xml += "<source_dest_check>#{escape(instance.source_dest_check)}</source_dest_check>\n"
      instances_xml += "<hypervisor>#{escape(instance.hypervisor)}</hypervisor>\n"
      instances_xml += "<network_interfaces>\n"
      instance.network_interfaces.each do |interface|
        instances_xml += "<network_interface>\n"
        instances_xml += "<network_interface_id>#{escape(interface.network_interface_id)}</network_interface_id>\n"
        instances_xml += "<vpc_id>#{escape(interface.vpc_id)}</vpc_id>\n"
        instances_xml += "<owner_id>#{escape(interface.owner_id)}</owner_id>\n"
        instances_xml += "<mac_address>#{escape(interface.mac_address)}</mac_address>\n"
        instances_xml += "<private_ip_address>#{escape(interface.private_ip_address)}</private_ip_address>\n"
        instances_xml += "<private_dns_name>#{escape(interface.private_dns_name)}</private_dns_name>\n"
        instances_xml += "<source_dest_check>#{escape(interface.source_dest_check)}</source_dest_check>\n"
        instances_xml += "<groups>\n"
        interface.groups.each do |group|
          instances_xml += "<group>\n"
          instances_xml += "<group name='#{group.group_name}'>#{escape(group.group_id)}</group>\n"
          instances_xml += "<group_name>#{escape(group.group_name)}</group_name>\n"
          instances_xml += "<group_id>#{escape(group.group_id)}</group_id>\n"
          instances_xml += "</group>\n"
        end
        instances_xml += "</groups>\n"
        instances_xml += "<attachment_attachment_id>#{escape(interface.attachment.attachment_id)}</attachment_attachment_id>\n"
        instances_xml += "<attachment_device_index>#{escape(interface.attachment.device_index)}</attachment_device_index>\n"
        instances_xml += "<attachment_status>#{escape(interface.attachment.status)}</attachment_status>\n"
        instances_xml += "<attachment_attach_time>#{escape(interface.attachment.attach_time.strftime("%Y-%m-%dT%e:%M:%S%z"))}</attachment_attach_time>\n"
        instances_xml += "<attachment_delete_on_termination>#{escape(interface.attachment.delete_on_termination)}</attachment_delete_on_termination>\n"
        if interface.association
          instances_xml += "<association_public_ip>#{escape(interface.association.public_ip)}</association_public_ip>\n"
          instances_xml += "<association_public_dns_name>#{escape(interface.association.public_dns_name)}</association_public_dns_name>\n"
          instances_xml += "<association_ip_owner_id>#{escape(interface.association.ip_owner_id)}</association_ip_owner_id>\n"
        end
        instances_xml += "<private_ip_addresses>\n"
        interface.private_ip_addresses.each do |ipaddr|
          instances_xml += "<private_ip_address>\n"
          instances_xml += "<private_ip_address>#{escape(ipaddr.private_ip_address)}</private_ip_address>\n"
          instances_xml += "<private_dns_name>#{escape(ipaddr.private_dns_name)}</private_dns_name>\n"
          instances_xml += "<primary>#{escape(ipaddr.primary)}</primary>\n"
          if ipaddr.association
            instances_xml += "<association_public_ip>#{escape(ipaddr.association.public_ip)}</association_public_ip>\n"
            instances_xml += "<association_public_dns_name>#{escape(ipaddr.association.public_dns_name)}</association_public_dns_name>\n"
            instances_xml += "<association_ip_owner_id>#{escape(ipaddr.association.ip_owner_id)}</association_ip_owner_id>\n"
          end
          instances_xml += "</private_ip_address>\n"
        end
        instances_xml += "</private_ip_addresses>\n"
        instances_xml += "</network_interface>\n"
      end
      instances_xml += "</network_interfaces>\n"
      if (instance.iam_instance_profile)
        instances_xml += "<iam_instance_profile_arn>#{escape(instance.iam_instance_profile.arn)}</iam_instance_profile_arn>\n"
        instances_xml += "<iam_instance_profile_id>#{escape(instance.iam_instance_profile.id)}</iam_instance_profile_id>\n"
      end
      instances_xml += "<ebs_optimized>#{escape(instance.ebs_optimized)}</ebs_optimized>\n"
      instances_xml += "<sriov_net_support>#{escape(instance.sriov_net_support)}</sriov_net_support>\n"

      instances_xml += "</instance>\n"
    end
    instances_xml += "</instances>"


    instance_ids_array=[]
    resp.instances.each do |instance|
      instance_ids_array.push(instance.instance_id)
    end


    <<-RESULTS
    <results>
      <result name="reservation_id">#{escape(resp.reservation_id)}</result>
      <result name="owner_id">#{escape(resp.owner_id)}</result>
      <result name="requester_id">#{escape(resp.requester_id)}</result>
      <result name="groups_xml">#{escape(groups_xml)}</result>
      <result name="groups_string">#{escape(resp.groups.to_s)}</result>
      <result name="instances_xml">#{escape(instances_xml)}</result>
      <result name="instances_string">#{escape(instance_ids_array.join(","))}</result>
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

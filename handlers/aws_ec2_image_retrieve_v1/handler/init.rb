# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2ImageRetrieveV1
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
    image = @ec2.describe_images
    require "pry";binding.pry
    .imagesSet.item[0]

    # Retrieve the specific machine properties.
    image_location = image.imageLocation
    image_state = image.imageState
	  image_ownerid = image.imageOwnerId
	  is_public = image.isPublic
	  arch = image.architecture
	  image_type = image.imageType
	  kernel_id = image.kernelId
	  image_owneralias = image.imageOwnerAlias
	  name = image.name
	  descrip = image.description
	  virt_type = image.virtualizationType
	  tag_set = image.tagSet

    # Build the results XML that will be returned by this handler.
    <<-RESULTS
    <results>
        <result name="Image Location">#{escape(image_location)}</result>
        <result name="Image State">#{escape(image_state)}</result>
        <result name="Owner Id">#{escape(image_ownerid)}</result>
        <result name="isPublic">#{escape(is_public)}</result>
        <result name="Architecture">#{escape(arch)}</result>
        <result name="Image Type">#{escape(image_type)}</result>
        <result name="Kernel Id">#{escape(kernel_id)}</result>
        <result name="Image Owner Alias">#{escape(image_owneralias)}</result>
        <result name="Name">#{escape(name)}</result>
        <result name="Description">#{escape(descrip)}</result>
		<result name="Virtualization Type">#{escape(virt_type)}</result>
		<result name="Tag Set">#{escape(tag_set)}</result>
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

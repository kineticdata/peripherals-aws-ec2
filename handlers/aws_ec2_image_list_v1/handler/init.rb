# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2ImageListV1
  # Prepare for execution by building Hash objects for necessary data and
  # configuration values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_doc - A REXML::Document object that represents the input XML.
  # * @access_key_id -  An info value used for AWS authentication.
  # * @secret_access_key - An info values used for AWS authentication.
  # * @ec2 - The AWS::EC2::Base object this handler uses to make API calls.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Construct an XML document to extract the parameter values
    @input_doc = REXML::Document.new(input)

    # Retrieve the credentials for the AWS session from the input XML string
    @access_key_id = get_info_value(@input_doc, 'access_key_id')
    @secret_access_key = get_info_value(@input_doc, 'secret_access_key')

    #Retrieve the instance id for use by the describe_instances call
    @perms = get_parameter_value(@input_doc, 'image_perms')
    @arch = get_parameter_value(@input_doc, 'image_arch')
	@type = get_parameter_value(@input_doc, 'image_type')
	@state = get_parameter_value(@input_doc, 'image_state')
				 
	# Create a base AWS object. This object contains all the methods for accessing
    # Amazon Web Services
    @ec2 = AWS::EC2::Base.new(:access_key_id => @access_key_id, :secret_access_key => @secret_access_key)
  end

  # This method essentially uses the describe_instances method provided by the
  # AWS::EC2::Base class to retrieve a list of instances.  The resulting instances
  # are parsed and their ids are used to build an XML list of instance ids to be
  # returned by this handler.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An XML formatted String representing the return variable results.
  def execute()
    # Because this handler will be used in a loop, we return an escaped XML string
    # for use by the Loop Handler's Data Source parameter.  The returned xml is
    # built as a string with each node of the <instances> element being an <instance>
    # which contains the Instance ID
    xml = '<images>'

	# We access each member of the instancesSet to retrieve the specific
    # machine instance and get the instanceId.  The instanceId is then set into
    # an XML string to return via the RESULTS string.  To correct some problems
    # with using "+" as a concatenation operator, we've opted to use "<<" instead.
	# This ensures we return a proper string into the RESULTS
	@ec2.describe_images.imagesSet.item.each do |images|
		if (@perms == "Public" && images.isPublic == "true" && (images.architecture == @arch || @arch == "all") && (images.imageType == @type || @type == "all") && (images.imageState == @state || @state == "all") )
			xml << "<image>" << images.imageId << "</image>"
		elsif (@perms == "Private" && images.isPublic != "true" && (images.architecture == @arch || @arch == "all") && (images.imageType == @type || @type == "all") && (images.imageState == @state || @state == "all"))
			xml << "<image>" << images.imageId << "</image>"
		elsif (@perms == "Both" && (images.architecture == @arch || @arch == "all") && (images.imageType == @type || @type == "all") && (images.imageState == @state || @state == "all"))
			xml << "<image>" << images.imageId << "</image>"
		end
    end
    xml << "</images>"
  
    # Build the results XML that will be returned by this handler.
    <<-RESULTS
      <results>
          <result name="Image List">#{escape(xml)}</result>
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

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_parameter_value(document, name)
    # Retrieve the XML node representing the desird info value
    parameter_element = REXML::XPath.first(document, "/handler/parameters/parameter[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    parameter_element.nil? ? nil : parameter_element.text
  end
end
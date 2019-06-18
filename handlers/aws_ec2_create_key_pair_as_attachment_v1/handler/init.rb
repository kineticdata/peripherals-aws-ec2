require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

class AwsEc2CreateKeyPairAsAttachmentV1
  java_import org.apache.http.impl.client.DefaultHttpClient
  java_import org.apache.http.client.methods.HttpPost
  java_import org.apache.http.util.EntityUtils
  java_import org.apache.http.entity.mime.MultipartEntity
  java_import org.apache.http.entity.mime.content.ByteArrayBody
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

    # Create Key Pair on AWS
    resp = @ec2.create_key_pair(
      dry_run: @parameters['dry_run'],
      key_name: @parameters['key_name']
    )
    puts "Key Pair successfully created in AWS" if @enable_debug_logging
    api_username    = URI.encode(@info_values["ce_username"])
    api_password    = @info_values["ce_password"]
    api_server      = @info_values["ce_server"]
    kapp_slug       = @parameters["kapp_slug"]
    form_slug       = @parameters["form_slug"]
    attach_field    = @parameters["attachment_field_name"]
    space_slug      = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]

    # Build Filename param
    filename = "#{@parameters["key_name"]}.pem"
    # Set file content variable
    file_content = resp.key_material

    puts "Attempting to upload the returned key pair to Filehub though the Request CE API" if @enable_debug_logging

    # Upload Attachment to Filehub
    http_client = DefaultHttpClient.new
    httppost = HttpPost.new("#{@info_values["ce_server"]}/#{space_slug}/#{@parameters["kapp_slug"]}/#{@parameters["form_slug"]}/files")
    httppost.setHeader("Authorization", "Basic " + Base64.encode64(api_username + ':' + api_password).gsub("\n",''))
    httppost.setHeader("Accept", "application/json")
    reqEntity = MultipartEntity.new
    byte = ByteArrayBody.new(file_content.to_java_bytes, "text/plain", filename)
    reqEntity.addPart("file", byte)
    httppost.setEntity(reqEntity)
    response = http_client.execute(httppost)
    entity = response.getEntity
    resp = EntityUtils.toString(entity)

    puts "Key pair successfully uploaded to Filehub" if @enable_debug_logging
    puts "Attempting to create a submission with the key pair attached to the field '#{attach_field}'" if @enable_debug_logging

    # Create Submission with attached file.
    api_route = "#{api_server}/#{space_slug}/app/api/v1/kapps/#{kapp_slug}/forms/#{form_slug}/submissions"
    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })
    puts "API route: '#{api_route}'" if @enable_debug_logging

    # Building the object that will be sent to Kinetic Core
    data = {}
    data.tap do |json|
      json[:values] = {"#{attach_field}" => resp}
    end
    puts "Data object that will be sent to Kinetic Core before parse: '#{data}'" if @enable_debug_logging

    # Post to the API
    response = resource.post(data.to_json, { :accept => "json", :content_type => "json" })
    puts "Response of API call: '#{response}'" if @enable_debug_logging

    # Parse the API Response
    submission = JSON.parse(response)
    submission_id = submission['submission']['id']

    <<-RESULTS
    <results>
      <result name="Submission Id">#{escape(submission_id)}</result>
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

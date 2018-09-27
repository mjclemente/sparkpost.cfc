component accessors="true" {

  property name="content" default="";
  property name="recipients" default="";
  property name="campaign_id" default="";
  property name="description" default="";
  property name="metadata" default="";
  property name="substitution_data" default="";
  property name="return_path" default="";
  property name="options";

  public any function init() {

    setContent( {} );
    setRecipients( [] );
    setMetadata( {} );
    setSubstitution_data( {} );
    setOptions( {} );

    variables.utcBaseDate = dateAdd( "l", createDate( 1970,1,1 ).getTime() * -1, createDate( 1970,1,1 ) );

    return this;
  }

  public any function from( required any email ) {
    variables[ 'content' ][ 'from' ] = parseEmail( email );
    return this;
  }

  public any function replyTo( required any email ) {
    variables[ 'content' ][ 'reply_to' ] = parseEmail( email ).email;
    return this;
  }

  public any function subject( required string subject ) {
    variables[ 'content' ][ 'subject' ] = subject;
    return this;
  }

  public any function usingTemplate( required string templateId, boolean useDraftTemplate = false ) {
    variables[ 'content' ][ 'template_id' ] = templateId;
    variables[ 'content' ][ 'use_draft_template' ] = use_draft_template;
    return this;
  }

  public any function html( required string message ) {
    variables[ 'content' ][ 'html' ] = message;
    return this;
  }

  public any function text( required string message ) {
    variables[ 'content' ][ 'text' ] = message;
    return this;
  }

  /**
  * @hint convenience method for setting both text/html and text/plain at the same time. You can either pass in the HTML content, and both will be set from it (using a method to strip the HTML for the plain text version), or you can call the method without an argument, after having set the HTML, and that will be used.
  */
  public any function textFromHtml( string message = '' ) {

    var textContent = getTextContent();
    if ( textContent.len() ) throw( 'The text/plain content has already been set.' );

    if ( !message.len() ) {

      var htmlContent = getHtmlContent();

      if ( !htmlContent.len() ) throw( 'The text/html content needs to be set prior to calling #getFunctionCalledName()# without the html argument.' );

      text( removeHTML( htmlContent ) );

    } else {
      text( removeHTML( message ) );
      html( message );
    }

    return this;
  }

  /**
  * @header Facilitates two means of setting a header. You can pass in a struct with a key/value pair for the name and value of the header. Alternatively, you can use this to pass in the name of the header, and provide the value as a second argument.
  */
  public any function header( required any header, any value ) {

    if ( !variables.content.keyExists( 'headers' ) )
      variables[ 'content' ][ 'headers' ] = {};

    if ( isStruct( header ) )
      variables.content.headers.append( header );
    else
      variables.content.headers[ header ] = value;

    return this;
  }

  /**
  * @hint If any headers were previously set, this method overwrites them.
  * @headers An object containing key/value pairs of header names and their value. You must ensure these are properly encoded if they contain unicode characters. Must not be any of the following reserved headers: Content-Type, Content-Transfer-Encoding, To, From, Subject, Reply-To
  */
  public any function headers( required struct headers ) {
    header( headers );
    return this;
  }

  /**
  * @hint Adds a NEW recipient envelope, with only the specified email address. The recipient can then be further customized with later commands
  */
  public any function to( required any email ) {
    addRecipient(
      {
        'address': parseEmail( email )
      }
    );
    return this;
  }

  /**
  * @hint Creates and sets a new recipient envelope
  * Documentation about recipients here: https://developers.sparkpost.com/api/recipient-lists.html
  */
  public void function addRecipient( required struct recipient ) {

    if ( !recipient.keyExists( 'address' ) ) throw( 'You must include at least one "address" within the recipient object.' );

    variables.recipients.append( recipient );
  }

  public any function returnPath( required string returnPath ) {
    setReturn_path( returnPath );
    return this;
  }

  /**
  * @hint appends a substitution ( "substitution_tag":"value to substitute" ) to the **current** recipient envelope. You can add a substitution by providing the tag and value to substitute, or by passing in a struct.
  * @substitution Facilitates two means of adding a substitution. You can pass in a struct with a tag/value for the substitution tag and value to substitute. Alternatively, you can use this argument to pass in the substitution tag, and provide the replacement value as a second argument.
  */
  public any function withSubstitution( any substitution, any value ) {
    var count = countRecipients();
    if ( !count ) throw( "You must add a recipient to this email before you can personalize substitutions" );

    if ( !variables.recipients[ count ].keyExists( 'substitution_data' ) )
      variables.recipients[ count ][ 'substitution_data' ] = {};

    if ( isStruct( substitution ) )
      variables.recipients[ count ][ 'substitution_data' ].append( substitution );
    else
      variables.recipients[ count ][ 'substitution_data' ][ substitution ] = value;

    return this;
  }

  /**
  * @hint sets the `substitutions` property for the **current** recipient envelope. If any substitutions were previously set, this method overwrites them.
  * @substitutions An object containing key/value pairs of substitution tags and their replacement values.
  */
  public any function withSubstitutions( required struct substitutions ) {
    var count = countRecipients();
    if ( !count ) throw( "You must add a recipient to this email before you can personalize substitutions." );

    variables.recipients[ count ][ 'substitution_data' ] = substitutions;

    return this;
  }

  /**
  * @hint appends a tag (text label) to the **current** recipient envelope.
  */
  public any function withTag( string tag ) {
    var count = countRecipients();
    if ( !count ) throw( "You must add a recipient to this email before you can personalize tags" );

    if ( !variables.recipients[ count ].keyExists( 'tags' ) )
      variables.recipients[ count ][ 'tags' ] = [];

      variables.recipients[ count ][ 'tags' ].append( tag );

    return this;
  }

  /**
  * @hint sets the `tags` property for the **current** recipient envelope. If any tags were previously set, this method overwrites them.
  * @tags Can be passed in as an array or comma separated list. Lists will be converted to arrays
  */
  public any function withTags( required any tags ) {
    var count = countRecipients();
    if ( !count ) throw( "You must add a recipient to this email before you can personalize tags." );

    if ( isArray( tags ) )
      variables.recipients[ count ][ 'tags' ] = tags;
    else
      variables.recipients[ count ][ 'tags' ] = tags.listToArray();

    return this;
  }

  public string function build() {

    var body = '';
    var properties = getPropertyValues();
    var count = properties.len();

    properties.each(
      function( property, index ) {

        var serializeMethod = 'serialize#property.key#';
        var value = { 'data': property.value };
        body &= '"#property.key#": ' & invoke( this, serializeMethod, value ) & '#index NEQ count ? "," : ""#';
      }
    );

    return '{' & body & '}';
  }

  private numeric function countRecipients() {
    return getRecipients().len();
  }

  private string function getHtmlContent() {
    if ( variables.content.keyExists( 'html' ) )
      return variables.content.html;
    else
      return '';
  }

  private string function getTextContent() {
    if ( variables.content.keyExists( 'text' ) )
      return variables.content.text;
    else
      return '';
  }

  /**
  * @hint If a struct is received, it is assumed it's in the proper format. Strings are parsed to check for bracketed email format
  */
  private struct function parseEmail( any email ) {
    if ( isStruct( email ) ) {
      return email;
    } else {
      var regex = '<([^>]+)>';
      var bracketedEmails = email.reMatchNoCase( regex );
      if ( bracketedEmails.len() ) {
        var bracketedEmail = bracketedEmails[1];
        var displayName = email.replacenocase( bracketedEmail, '' ).trim();
        var parsedEmail = { 'email' : bracketedEmail.REReplace( '[<>]', '', 'all') };

        if ( displayName.len() )
          parsedEmail[ 'name' ] = displayName;

        return parsedEmail;

      } else {
        return {
          'email' : email
        };

      }
    }
  }

  /**
  * @hint helper that forces object value serialization to strings. This is needed in some cases, where CF's loose typing causes problems
  */
  private string function serializeValuesAsString( required struct data ) {
    var serializedData = data.reduce(
      function( result, key, value ) {

        if ( result.len() ) result &= ',';

        return result & '"#key#": "#value#"';
      }, ''
    );
    return '{' & serializedData & '}';
  }

  private numeric function getUTCTimestamp( required date dateToConvert ) {
    return dateDiff( "s", variables.utcBaseDate, dateToConvert );
  }

  private date function parseUTCTimestamp( required numeric utcTimestamp ) {
    return dateAdd( "s", utcTimestamp, variables.utcBaseDate );
  }

  /** This could probably go in a separate utils CFC, but it's here for now
  * Removes All HTML from a string removing tags, script blocks, style blocks, and replacing special character code.
  *
  * @author Scott Bennett (scott@coldfusionguy.com)
  * @version 1, November 14, 2007
  */
  private string function removeHTML( required string source ){

    // Remove all spaces becuase browsers ignore them
    var result = ReReplace(trim(source), "[[:space:]]{2,}", " ","ALL");

    // Remove the header
    result = ReReplace(result, "<[[:space:]]*head.*?>.*?</head>","", "ALL");

    // remove all scripts
    result = ReReplace(result, "<[[:space:]]*script.*?>.*?</script>","", "ALL");

    // remove all styles
    result = ReReplace(result, "<[[:space:]]*style.*?>.*?</style>","", "ALL");

    // insert tabs in spaces of <td> tags
    result = ReReplace(result, "<[[:space:]]*td.*?>","  ", "ALL");

    // insert line breaks in places of <BR> and <LI> tags
    result = ReReplace(result, "<[[:space:]]*br[[:space:]]*>",chr(13), "ALL");
    result = ReReplace(result, "<[[:space:]]*li[[:space:]]*>",chr(13), "ALL");

    // insert line paragraphs (double line breaks) in place
    // if <P>, <DIV> and <TR> tags
    result = ReReplace(result, "<[[:space:]]*div.*?>",chr(13), "ALL");
    result = ReReplace(result, "<[[:space:]]*tr.*?>",chr(13), "ALL");
    result = ReReplace(result, "<[[:space:]]*p.*?>",chr(13), "ALL");

    // Remove remaining tags like <a>, links, images,
    // comments etc - anything thats enclosed inside < >
    result = ReReplace(result, "<.*?>","", "ALL");

    // replace special characters:
    result = ReReplace(result, "&nbsp;"," ", "ALL");
    result = ReReplace(result, "&bull;"," * ", "ALL");
    result = ReReplace(result, "&lsaquo;","<", "ALL");
    result = ReReplace(result, "&rsaquo;",">", "ALL");
    result = ReReplace(result, "&trade;","(tm)", "ALL");
    result = ReReplace(result, "&frasl;","/", "ALL");
    result = ReReplace(result, "&lt;","<", "ALL");
    result = ReReplace(result, "&gt;",">", "ALL");
    result = ReReplace(result, "&copy;","(c)", "ALL");
    result = ReReplace(result, "&reg;","(r)", "ALL");

    // Remove all others. More special character conversions
    // can be added above if needed
    result = ReReplace(result, "&(.{2,6});", "", "ALL");

    // Thats it.
    return result;

  }

  /**
  * @hint converts the array of properties to an array of their keys/values, while filtering those that have not been set
  */
  private array function getPropertyValues() {

    var propertyValues = getProperties().map(
      function( item, index ) {
        return {
          "key" : item.name,
          "value" : getPropertyValue( item.name )
        };
      }
    );

    return propertyValues.filter(
      function( item, index ) {
        if ( isStruct( item.value ) )
          return !item.value.isEmpty();
        else
          return item.value.len();
      }
    );
  }

  private array function getProperties() {

    var metaData = getMetaData( this );
    var properties = [];

    for( var prop in metaData.properties ) {
      properties.append( prop );
    }

    return properties;
  }

  private any function getPropertyValue( string key ){
    var method = this["get#key#"];
    var value = method();
    return value;
  }

  /**
  * @hint currently in place to provide a standard fallback when a custom serialization method isn't needed (i.e. most cases)
  */
  public any function onMissingMethod ( string missingMethodName, struct missingMethodArguments ) {
    var action = missingMethodName.left( 9 );
    var property = missingMethodName.right( missingMethodName.len() - 9 );

    if ( action == 'serialize' ) {

      if ( !missingMethodArguments.isEmpty() )
        return serializeJson( missingMethodArguments.data );
      else
        throw "#missingMethodName#() called without an argument";

    } else {
      var message = "no such method (" & missingMethodName & ") in " & getMetadata( this ).name & "; [" & structKeyList( this ) & "]";
      throw "#message#";
    }

  }

}
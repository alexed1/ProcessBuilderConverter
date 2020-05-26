public with sharing class ValidateMetadata {
    
    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

    public static string validate(String flowMetadata) {
        String validityProblemString = '';
        Dom.Document doc = new Dom.Document();
        doc.load(flowMetadata);
        //Retrieve the root element for this document.

        Dom.XMLNode flowXML = doc.getRootElement();
        //Flow currently doesn't support Scheduled Actions as part of a record change-triggered Flow, so filter out flows with Pause element
        Dom.XmlNode waitNodes = flowXML.getChildElement('waits', SOAP_NS);
        if (waitNodes != null)
            validityProblemString = validityProblemString + 'Triggers in Flow Builder do not currently support Scheduled Actions, and this Process Builder process has at least 1. \n';


        return validityProblemString;
    }
}

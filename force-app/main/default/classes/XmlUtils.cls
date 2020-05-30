public with sharing class XmlUtils {

    public static String SOAP_NS = 'http://soap.sforce.com/2006/04/metadata';

   
    public static Dom.XmlNode changeTextValue(String newTextValue, Dom.XmlNode curNode) {
        List<Dom.XmlNode> childList = curNode.getChildren();
        for (Dom.XmlNode curChild : childList) {
            if (curChild.getNodeType().name() == 'TEXT') {
                curNode.removeChild(curChild);
                curNode.addTextNode(newTextValue);
            }
        }
        return curNode;
    }


    public static String getProcessMetadataValue(Dom.XmlNode curPMV) {
        String targetValue;
       // System.debug ('curPMV is: ' + curPMV);
        Dom.XmlNode pmvValueElement = curPMV.getChildElement('value', SOAP_NS);
       // System.debug ('pmvValueElement is: ' + pmvValueElement);
        if (pmvValueElement.getChildElement('elementReference', SOAP_NS) != null) {
            targetValue = pmvValueElement.getChildElement('elementReference', SOAP_NS).getText();
        } else if (pmvValueElement.getChildElement('stringValue', SOAP_NS) != null) {
            targetValue = pmvValueElement.getChildElement('stringValue', SOAP_NS).getText();
        } else if (pmvValueElement.getChildElement('numberValue', SOAP_NS) != null){
            targetValue = pmvValueElement.getChildElement('numberValue', SOAP_NS).getText();
        } else throw new PBConvertException('tried to get a value from a node but could get the right type');
        
        System.debug('targetValue is: ' + targetValue);
        return targetValue;

    }

    public static Dom.XmlNode getChildProcessMetadataValueByName(Dom.XmlNode flowXML, String pmvTargetName) {
        for(Dom.XMLNode pmv : flowXML.getChildElements()) {
           // System.debug('current child element of flow is: ' + pmv);
            if (pmv.getName() == 'processMetadataValues') {
                //System.debug ('this one has the name processMetadataValue'); 
                for (Dom.XMLNode pmvChild : pmv.getChildElements()){
                    //System.debug('the current child of the processmetadatavalue element is ' + pmvChild);
                    if (pmvChild.getName() == 'name') {
                       // System.debug ('this child is named name');
                        if (pmvChild.getText() == pmvTargetName) {
                            System.debug ('theres a match between the value of this element and the passed in value: ' + pmvTargetName);
                            return pmv;
                        }
                    }
                }
            }
            
        }
        throw new PBConvertException('tried  but failedto find a node with the name: '+ pmvTargetName);
 
    }

    public class PBConvertException extends Exception{}
}

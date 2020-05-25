public with sharing class XmlUtils {
   
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
}

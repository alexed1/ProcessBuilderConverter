/* Apex Controller for Lightning Web Component for Flow Screens:    flowPickerFSC
                                                                    FlowListController.cls

Allows the selection of a Flow

12/20/19 - Eric Smith - Version 1.3
                        Added labels for the configuration attributes,
                        added help text for the configuration attributes,
                        added support for changing the default placeholder text,  
                        added a search string to filter the list of flows,
                        sorted the list to display in alphabetical order by Flow Label,
                        added an attribute to specify the width of the component,
                        added a method to expose the selected Flow API Name to a calling component,
                        and created a Test Class so the component can be packaged

*/

global with sharing class FlowListController {

    @AuraEnabled(cacheable=true)
    public static List<FlowDefinitionView> getFlowNamesApex(String filtersString) {
        System.debug('filtersString is: ' + filtersString);
        String queryString = 'SELECT Id, ApiName, Label FROM FlowDefinitionView ';

        if (filtersString != null) {
            Map<String, List<String>> filters = (Map<String, List<String>>) JSON.deserialize(filtersString, Map<String, List<String>>.class);
            System.debug('filters is: ' + filters);
            if (!filters.isEmpty()) {
                queryString += ' WHERE ';
                Boolean isFirst = true;
                for (String fieldName : filters.keySet()) {
                    List<String> values = filters.get(fieldName); //'ProcessBuilder' ? 'Wrokflow' : filters.get(fieldName);
                    for(String value : values) {
                        value = (value == 'ProcessBuilder') ? 'Wrokflow' : value;
                        //System.debug('values ' + value + values);
                    }
                    String negativeClause = fieldName.contains('!') ? (values.size() > 1 ? 'NOT ' : '!') : '';
                    String operator = fieldName.contains('Label') ? 'LIKE ' : (values.size() == 1 ? '= ' : 'IN ');  // Updated to Handle Search String
                    String value = values.size() == 1 ?  '\'' + values[0] + '\'' : '(\'' + String.join(values, '\',\'') + '\')';
                    queryString += (!isFirst ? ' AND ' : ' ') + fieldName.replace('!', '') + ' ' + negativeClause + operator + value;
                    isFirst = false;
                }
            }
        }
        // Sort the results by the FLow Label
        queryString += ' ORDER BY Label ASC';
        System.debug('query string is: ' + queryString);
        return (List<FlowDefinitionView>) Database.query(queryString);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getWFRDataApex() {
        List<String> curWFRNames = new List<String>();
        System.debug('entering getWFRDataApex');
        MetadataService.MetadataPort service = RetrieveMetadata.createService();				
          
        List<MetadataService.ListMetadataQuery> queries = new List<MetadataService.ListMetadataQuery>();        
        MetadataService.ListMetadataQuery queryWorkflow = new MetadataService.ListMetadataQuery();
        queryWorkflow.type_x = 'WorkflowRule';
        queries.add(queryWorkflow);     
           
        MetadataService.FileProperties[] fileProperties = service.listMetadata(queries, 25);
        for(MetadataService.FileProperties fileProperty : fileProperties){
            String curWFRdef =  fileProperty.fullName;
            System.debug(fileProperty.fullName);
            curWFRNames.add(curWFRdef);
        }
           
        System.debug (curWFRNames);
        return curWFRNames;

    }

   
}

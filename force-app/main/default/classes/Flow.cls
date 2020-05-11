public with sharing class Flow {
        public static String SOAP_M_URI = 'http://soap.sforce.com/2006/04/metadata';
        @auraEnabled
        public String type = 'Flow';
        @auraEnabled
        public String fullName;
        private String[] fullName_type_info = new String[]{'fullName',SOAP_M_URI,null,'0','1','false'};
        @auraEnabled
        public MetadataService.FlowActionCall[] actionCalls;
        @auraEnabled
        public MetadataService.FlowApexPluginCall[] apexPluginCalls;
        @auraEnabled
        public MetadataService.FlowAssignment[] assignments;
        @auraEnabled
        public MetadataService.FlowChoice[] choices;
        @auraEnabled
        public MetadataService.FlowConstant[] constants;
        @auraEnabled
        public MetadataService.FlowDecision[] decisions;
        @auraEnabled
        public String description;
        @auraEnabled
        public MetadataService.FlowDynamicChoiceSet[] dynamicChoiceSets;
        @auraEnabled
        public MetadataService.FlowFormula[] formulas;
        @auraEnabled
        public String interviewLabel;
        @auraEnabled
        public String label;
        @auraEnabled
        public MetadataService.FlowLoop[] loops;
        @auraEnabled
        public MetadataService.FlowMetadataValue[] processMetadataValues;
        @auraEnabled
        public String processType;
        @auraEnabled
        public MetadataService.FlowRecordCreate[] recordCreates;
        @auraEnabled
        public MetadataService.FlowRecordDelete[] recordDeletes;
        @auraEnabled
        public MetadataService.FlowRecordLookup[] recordLookups;
        @auraEnabled
        public MetadataService.FlowRecordUpdate[] recordUpdates;
        @auraEnabled
        public MetadataService.FlowScreen[] screens;
        @auraEnabled
        public MetadataService.FlowStage[] stages;
        @auraEnabled
        public String startElementReference;
        @auraEnabled
        public MetadataService.FlowStep[] steps;
        @auraEnabled
        public MetadataService.FlowSubflow[] subflows;
        @auraEnabled
        public MetadataService.FlowTextTemplate[] textTemplates;
        @auraEnabled
        public MetadataService.FlowVariable[] variables;
        @auraEnabled
        public MetadataService.FlowWait[] waits;
        private String[] actionCalls_type_info = new String[]{'actionCalls',SOAP_M_URI,null,'0','-1','false'};
        private String[] apexPluginCalls_type_info = new String[]{'apexPluginCalls',SOAP_M_URI,null,'0','-1','false'};
        private String[] assignments_type_info = new String[]{'assignments',SOAP_M_URI,null,'0','-1','false'};
        private String[] choices_type_info = new String[]{'choices',SOAP_M_URI,null,'0','-1','false'};
        private String[] constants_type_info = new String[]{'constants',SOAP_M_URI,null,'0','-1','false'};
        private String[] decisions_type_info = new String[]{'decisions',SOAP_M_URI,null,'0','-1','false'};
        private String[] description_type_info = new String[]{'description',SOAP_M_URI,null,'0','1','false'};
        private String[] dynamicChoiceSets_type_info = new String[]{'dynamicChoiceSets',SOAP_M_URI,null,'0','-1','false'};
        private String[] formulas_type_info = new String[]{'formulas',SOAP_M_URI,null,'0','-1','false'};
        private String[] interviewLabel_type_info = new String[]{'interviewLabel',SOAP_M_URI,null,'0','1','false'};
        private String[] label_type_info = new String[]{'label',SOAP_M_URI,null,'1','1','false'};
        private String[] loops_type_info = new String[]{'loops',SOAP_M_URI,null,'0','-1','false'};
        private String[] processMetadataValues_type_info = new String[]{'processMetadataValues',SOAP_M_URI,null,'0','-1','false'};
        private String[] processType_type_info = new String[]{'processType',SOAP_M_URI,null,'0','1','false'};
        private String[] recordCreates_type_info = new String[]{'recordCreates',SOAP_M_URI,null,'0','-1','false'};
        private String[] recordDeletes_type_info = new String[]{'recordDeletes',SOAP_M_URI,null,'0','-1','false'};
        private String[] recordLookups_type_info = new String[]{'recordLookups',SOAP_M_URI,null,'0','-1','false'};
        private String[] recordUpdates_type_info = new String[]{'recordUpdates',SOAP_M_URI,null,'0','-1','false'};
        private String[] screens_type_info = new String[]{'screens',SOAP_M_URI,null,'0','-1','false'};
        private String[] stages_type_info = new String[]{'stages',SOAP_M_URI,null,'0','-1','false'};
        private String[] startElementReference_type_info = new String[]{'startElementReference',SOAP_M_URI,null,'0','1','false'};
        private String[] steps_type_info = new String[]{'steps',SOAP_M_URI,null,'0','-1','false'};
        private String[] subflows_type_info = new String[]{'subflows',SOAP_M_URI,null,'0','-1','false'};
        private String[] textTemplates_type_info = new String[]{'textTemplates',SOAP_M_URI,null,'0','-1','false'};
        private String[] variables_type_info = new String[]{'variables',SOAP_M_URI,null,'0','-1','false'};
        private String[] waits_type_info = new String[]{'waits',SOAP_M_URI,null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{SOAP_M_URI,'true','false'};
        private String[] type_att_info = new String[]{'xsi:type'};
        private String[] field_order_type_info = new String[]{'fullName', 'actionCalls','apexPluginCalls','assignments','choices','constants','decisions','description','dynamicChoiceSets','formulas','interviewLabel','label','loops','processMetadataValues','processType','recordCreates','recordDeletes','recordLookups','recordUpdates','screens','stages','startElementReference','steps','subflows','textTemplates','variables','waits'};
    }


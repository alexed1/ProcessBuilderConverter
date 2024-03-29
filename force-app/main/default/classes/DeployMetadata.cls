public with sharing class DeployMetadata {
 
    @AuraEnabled 
    public static String deploy(String metadataText, String metadataName, String testLevel, String objectType) {
        System.debug('entering deploy. metadata text, objectname, testlevel, and object type are:' );
       System.debug ('metadataText: ' + metadataText);
       metadataName = metadataName.replace('.', '_').replace(' ', '_');
        System.debug ('objectName: ' + metadataName);
        System.debug ('testLevel: ' + testLevel);
        System.debug ('objectType: ' + objectType);
        usf.MetadataService.MetadataPort service = createService();
        if (String.isEmpty(testLevel))
            testLevel = 'NoTestRun';

        String zippedClass = generateZipfile(metadataText, metadataName, objectType);
        usf.MetadataService.AsyncResult deployResult= service.deploy(zippedClass, getDeployOptions());

        String jobId = deployResult.id;
        usf.MetadataService.DeployResult result = service.checkDeployStatus(jobId,true);
        System.debug('deploy status is: ' + metadataName + ' ' + result.status + ' ' + result.stateDetail); 
        return jobId;
    }

    @auraEnabled
	public static String checkAsyncRequest(String jobId) {
        System.debug('entering checkAsyncRequest, job id: ' + jobId);
		// Check the status of the retrieve request
		usf.MetadataService.MetadataPort service = createService();
        usf.MetadataService.DeployResult deployResult = service.checkDeployStatus(jobId, true);
        System.debug('returned from checkDeployStatus call to metadata service. deploy result is: ' + deployResult);
		if(deployResult.done)
		{
			// Errors?
			if(deployResult.status != 'Succeeded')
			{   
                System.debug ('status is: ' + deployResult.status);
                System.debug ('error is: ' + deployResult.errorMessage);
                String problems = '';
                System.debug('deploy result:' + deployResult.details.componentFailures);
                System.debug('deploy success:' + deployResult.details.componentSuccesses);
                for(usf.MetadataService.DeployMessage curMessage : deployResult.details.componentFailures) {
                    problems = problems + '\n' + curMessage.problem;
                }
                System.debug('problem is: ' + problems);
			    return problems;				
			}
			else
			{
                System.debug('deploy succeeded');
			 
                return 'success';
			}
		}
		else return 'inprocess';
	}
        

    public static String generateZipfile(String classText, String objectName, String objectType) {
            usf.Zippex sampleZip = new usf.Zippex();
            System.debug('assembling package with objectName: ' + objectName);
            Blob fileData = Blob.valueOf(getPackageXml(objectName, objectType));
            System.debug('preparing to deploy package.xml: ' + fileData.toString());
            sampleZip.addFile('package.xml', fileData, null);
           // fileData = Blob.valueOf(getObjectMetadata(objectType));
           // System.debug('preparing to deploy meta file: ' + fileData.toString());
           // sampleZip.addFile(  'flows/' + objectName + '.flow-meta.xml', fileData, null);
            fileData = Blob.valueOf(classText);
            System.debug('preparing to deploy object file: ' + fileData.toString());
            sampleZip.addFile( 'flows/' + objectName +'.flow', fileData, null);
            return EncodingUtil.base64Encode(sampleZip.getZipArchive());

        }
    public static usf.MetadataService.DeployOptions getDeployOptions(){
             
        usf.MetadataService.DeployOptions curDeployOption = new usf.MetadataService.DeployOptions();
        curDeployOption.allowMissingFiles = false;
        curDeployOption.autoUpdatePackage = true;
        curDeployOption.checkOnly = false;
        curDeployOption.ignoreWarnings = true;
        curDeployOption.performRetrieve = false;
        curDeployOption.purgeOnDelete = false;
        curDeployOption.rollbackOnError = true;
        curDeployOption.runTests = new String[]{};
        curDeployOption.singlePackage = true;
        curDeployOption.testLevel = 'NoTestRun';
           
        return curDeployOption;
        }

        private static usf.MetadataService.MetadataPort createService()
        { 
            usf.MetadataService.MetadataPort service = new usf.MetadataService.MetadataPort();
            service.SessionHeader = new usf.MetadataService.SessionHeader_element();
            service.SessionHeader.sessionId = UserInfo.getSessionId();
            return service;		
        }	

        public static String getPackageXml(String className, String objectType)
        {
            return '<?xml version=\"1.0\" encoding=\"UTF-8\"?>' + 
                '<Package xmlns=\"http://soap.sforce.com/2006/04/metadata\">' + 
                    '<types>' + 
                        '<members>' + className + '</members>' +
                        '<name>' + objectType +'</name>' + 
                    '</types>' + 
                    '<version>51.0</version>' + 
                '</Package>';		
        }
    
        public static String getObjectMetadata(String objectName)
        {
            String boilerplate =  '<?xml version="1.0" encoding="UTF-8"?>' +
            '<Flow xmlns="http://soap.sforce.com/2006/04/metadata">' +
                '<apiVersion>51.0</apiVersion>' + 
                '<status>Active</status>' +
            '</Flow>';

            boilerplate = boilerplate.replace('ObjectName', objectName);
            return boilerplate;
	
        }

        
            

}

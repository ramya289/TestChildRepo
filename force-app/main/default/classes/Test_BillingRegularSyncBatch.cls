@IsTest
private class Test_BillingRegularSyncBatch {
    @testSetup
    static void setup() {
        String uniqueUserName = 'testuser' + DateTime.now().getTime() + '@testorg.com';
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1 ];
        User user = new User(Alias = 'TestUser', Email = 'testuser@testorg.com', EmailEncodingKey = 'UTF-8', LastName = 'Testing', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = prof.Id, TimeZoneSidKey = 'America/Los_Angeles', UserName = uniqueUserName);
        insert user;
        String adminPSName = BreadwinnerBillingUtil.BB_ADMIN_PS_NAME;
        List<PermissionSet> pset = [SELECT Id FROM PermissionSet WHERE Name = :adminPSName];
        insert new PermissionSetAssignment(AssigneeId = user.id, PermissionSetId = pset[0].Id);
    }
    @IsTest
    static void stripe_RegularSync_When_Success() {
        User adminUser =  [SELECT Id FROM User WHERE Alias = 'TestUser' LIMIT 1];
        System.runAs(adminUser){
            BWP_Processor_Config__c apc = UnitTests.createPayConfig(ProcessorUtil.PAT_STRIPE);
            Test.startTest();
            UnitTests.MockHttpResponse httpMock = new UnitTests.MockHttpResponse();
            httpMock.response = '{"object":"list","url":"/v1/products","has_more":false,"data":[{"id":"prod_KpVxdk3go54zWs","object":"product","active":true,"created":1640264496,"description":null,"images":[],"livemode":false,"metadata":{},"name":"Golf Ball","package_dimensions":null,"shippable":null,"statement_descriptor":null,"tax_code":null,"unit_label":null,"updated":1640264496,"url":null}]}';
            Test.setMock(HttpCalloutMock.class, httpMock);
            BillingRegularSyncBatch RegularSync = new BillingRegularSyncBatch('Product');
            Database.executeBatch(RegularSync, 1);
            Test.stopTest();
            BWP_Product__c product = [Select Id, Name FROM BWP_Product__c LIMIT 1];
            system.assertEquals('Golf Ball', product.Name);
        }
    }
    
    @IsTest
    static void stripe_RegularSync_When_Failure() {
        User adminUser =  [SELECT Id FROM User WHERE Alias = 'TestUser' LIMIT 1];
        System.runAs(adminUser){
            BWP_Processor_Config__c apc = UnitTests.createPayConfig(ProcessorUtil.PAT_STRIPE);
            Test.startTest();
            UnitTests.MockHttpResponse httpMock = new UnitTests.MockHttpResponse();
            httpMock.response = '{"object":"list","data":[],"has_more":false,"url":"/v1/products"}';
            httpMock.statusCode = 400;
            Test.setMock(HttpCalloutMock.class, httpMock);
            BillingRegularSyncBatch RegularSync = new BillingRegularSyncBatch('Product');
            Database.executeBatch(RegularSync, 1);
            Test.stopTest();
            List<BWP_Product__c> productsList = [Select Id, Name FROM BWP_Product__c];
            System.assert(productsList.size()==0);
        }
    }
}
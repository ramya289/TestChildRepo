@IsTest
private class Test_BillingHistoricalSyncBatch {
    @testSetup
    static void setup() {
        String uniqueUserName = 'testuser' + DateTime.now().getTime() + '@testorg.com';
        Profile prof = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1 ];
        User user = new User(Alias = 'TestUser', Email = 'testuser@testorg.com', EmailEncodingKey = 'UTF-8', LastName = 'Testing', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US', ProfileId = prof.Id, TimeZoneSidKey = 'America/Los_Angeles', UserName = uniqueUserName);
        insert user;
        String adminPSName = 'Breadwinner_Payments_Admin_User';
        List<PermissionSet> pset = [SELECT Id FROM PermissionSet WHERE Name = :adminPSName];
        List<PermissionSet> pset1 = [SELECT Id FROM PermissionSet WHERE Name = 'Breadwinner_Billing'];
        insert new PermissionSetAssignment(AssigneeId = user.id, PermissionSetId = pset[0].Id);
        insert new PermissionSetAssignment(AssigneeId = user.id, PermissionSetId = pset1[0].Id);
    }
    @IsTest
    static void stripe_HistoricalSync_When_Success() {
        User adminUser =  [SELECT Id FROM User WHERE Alias = 'TestUser' LIMIT 1];
        System.runAs(adminUser){
            BWP_Processor_Config__c apc = UnitTests.createPayConfig(ProcessorUtil.PAT_STRIPE);
            Test.startTest();
            UnitTests.MockHttpResponse httpMock = new UnitTests.MockHttpResponse();
            httpMock.response = '{"object":"list","url":"/v1/products","has_more":false,"data":[{"id":"prod_KpVxdk3go54zWs","object":"product","active":true,"created":1640264496,"description":null,"images":[],"livemode":false,"metadata":{},"name":"Sushmitha","package_dimensions":null,"shippable":null,"statement_descriptor":null,"tax_code":null,"unit_label":null,"updated":1640264496,"url":null}]}';
            Test.setMock(HttpCalloutMock.class, httpMock);
            BillingHistoricalSyncBatch historicalSync = new BillingHistoricalSyncBatch('Product');
            Database.executeBatch(historicalSync, 1);
            Test.stopTest();
        }
    }
    
    @IsTest
    static void stripe_HistoricalSync_When_Failure() {
        User adminUser =  [SELECT Id FROM User WHERE Alias = 'TestUser' LIMIT 1];
        System.runAs(adminUser){
            BWP_Processor_Config__c apc = UnitTests.createPayConfig(ProcessorUtil.PAT_STRIPE);
            Test.startTest();
            UnitTests.MockHttpResponse httpMock = new UnitTests.MockHttpResponse();
            httpMock.response = '{"object":"list","data":[],"has_more":false,"url":"/v1/products"}';
            httpMock.statusCode = 400;
            Test.setMock(HttpCalloutMock.class, httpMock);
            BillingHistoricalSyncBatch historicalSync = new BillingHistoricalSyncBatch('Product');
            Database.executeBatch(historicalSync, 1);
            Test.stopTest();
        }
    }
}
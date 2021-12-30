@IsTest
private class Test_BillingRecordInfoExtension {
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
    private static void ProductRecordInfo() {
        User adminUser =  [SELECT Id FROM User WHERE Alias = 'TestUser' LIMIT 1];
        System.runAs(adminUser){
            BillingUnitTests.products(1);
            List<String> breadWinnerFieldsList = new List<String> ();
            for (Schema.SObjectField field: BWP_Product__c.sObjectType.getDescribe().fields.getMap().values()) {
                breadWinnerFieldsList.add(field.getDescribe().getName());
            }
                        
            BWP_Product__c testProduct = Database.query('Select ' + String.join(breadWinnerFieldsList, ', ') + ' FROM BWP_Product__c LIMIT 1');
            PageReference pageRef = Page.ProductRecordInfo;
            pageRef.getParameters().put('id', String.valueOf(testProduct.Id));
            pageRef.getParameters().put('showBWLayout', 'true');
            Test.setCurrentPage(pageRef);
            Test.setMock(HttpCalloutMock.class, new UnitTests.MockHttpResponse());
            ApexPages.StandardController sc = new ApexPages.StandardController(testProduct);
            BillingRecordInfoExtension productInfo = new BillingRecordInfoExtension(sc);
        }
    }
}
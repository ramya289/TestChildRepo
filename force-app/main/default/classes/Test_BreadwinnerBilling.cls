@IsTest
private class Test_BreadwinnerBilling {
    @IsTest
    private static void Test_fetchProducts() {
        BWP_Processor_Config__c bpc = new BWP_Processor_Config__c();
        bpc.Payment_Processor_Type__c = 'Stripe';
        bpc.Access_Token__c = 'TEST_TOKEN';
        BreadwinnerUtil.isBreadwinnerTransaction = true;
        insert bpc;
        BreadwinnerBilling bb = new BreadwinnerBilling();
        bb.checkRemoteSites();
        bb.fetchProducts();
    }
    @IsTest
    private static void Test_ProductWrapper() {
        BreadwinnerBilling.Product prod = new BreadwinnerBilling.Product();
        prod.name = 'Test Product';
        prod.active = 'false';
        prod.description = 'Test Description';
        prod.type = 'service';
    }
}
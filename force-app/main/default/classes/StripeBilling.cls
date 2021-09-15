public with sharing class StripeBilling {
    public BWP_Processor_Config__c processorConfig;
    public Boolean isProductsListEmpty                  {get;set;}
    public Boolean isStripeConnected                    {get;set;}
    public List<Product> productsList                   {get;set;}
    public Boolean showProducts 				        {get;set;}
    public StripeBilling() {
        processorConfig = BreadwinnerUtil.processorConfigList().size() > 0 ? BreadwinnerUtil.processorConfigList()[0] : new BWP_Processor_Config__c()
        productsList = new List<Product>();
        isStripeConnected = BreadwinnerUtil.processorConfigList().size() > 0;
        isProductsListEmpty = true;
        showProducts = false;
    }
    public void fetchProducts() {
        processorConfig = BreadwinnerUtil.processorConfigList().size() > 0 ? CryptoUtil.decryptSecrets(BreadwinnerUtil.processorConfigList()[0]) : new BWP_Processor_Config__c();
        String endPoint = stripeBaseUrlv1 + '/products?limit=15';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endPoint);
        req.setHeader('Authorization', 'Bearer ' + processorConfig.Access_Token__c);
        req.setMethod('GET');
        try {
            Http h = new Http();
            HttpResponse res = new HttpResponse();
            if(!Test.isRunningTest()) {
                res = h.send(req);
            } else {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"object":"list","data":[{"id":"{CH_ID}","object":"charge","amount":200000,"amount_refunded":0,"application":null,"application_fee":null,"application_fee_amount":null,"balance_transaction":"{TXN_ID}","captured":true,"created":1548335430,"currency":"usd","customer":"{CUS_ID}","description":"Payment for invoice 4543104-0001","destination":null,"dispute":null,"failure_code":null,"failure_message":null,"fraud_details":{},"invoice":"{INV_ID}","livemode":false,"metadata":{},"on_behalf_of":null,"order":null,"outcome":{"network_status":"approved_by_network","reason":null,"risk_level":"normal","risk_score":31,"seller_message":"Payment complete.","type":"authorized"},"paid":true,"payment_intent":null,"receipt_email":null,"receipt_number":"2135-8515","receipt_url":"https://pay.stripe.com/receipts/acct_test/ch_test/rcpt_test","refunded":false,"refunds":{"object":"list","data":[],"has_more":false,"total_count":0,"url":"/v1/charges/ch_test/refunds"},"review":null,"shipping":null,"source":{"id":"{SRC_ID}","object":"source","amount":null,"card":{"exp_month":12,"exp_year":2021,"address_zip_check":"pass","brand":"MasterCard","country":"US","cvc_check":"pass","fingerprint":"rlVW6h291ivmHi02","funding":"debit","last4":"8210","three_d_secure":"optional","name":null,"address_line1_check":null,"tokenization_method":null,"dynamic_last4":null},"client_secret":"{CLIENT_SECRET}","created":1548335431,"currency":null,"customer":"{CUS_ID}","flow":"none","livemode":false,"metadata":{},"owner":{"address":{"city":null,"country":null,"line1":null,"line2":null,"postal_code":"99501","state":null},"email":null,"name":null,"phone":null,"verified_address":null,"verified_email":null,"verified_name":null,"verified_phone":null},"statement_descriptor":null,"status":"chargeable","type":"card","usage":"reusable"},"source_transfer":null,"statement_descriptor":null,"status":"succeeded","transfer_data":null,"transfer_group":null}],"has_more":false,"url":"/v1/charges"}');
                res.setStatusCode(200);
            }
            if(res.getStatusCode() == 200) { //OK
                
                String responseStr = replaceStandardTypes(res.getbody());
                
                JSONParser parser = JSON.createParser(responseStr);
                ProductsResponse responseData = (ProductsResponse) parser.readValueAs(ProductsResponse.class);
                for(Product c : responseData.data) {
                    c.paymentDate = DateTime.newInstance((long)(c.created) * 1000);
                    c.amount = c.amount/100;
                }
                productsList = responseData.data;
                if(responseData.data.size()>0) {
                    isProductsListEmpty = false;
                    showProducts = true;
                } else {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, ' No Products found.'));
                }
            } else { // Failed
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ' Error occurred while fetching Products. Please try again or contact Breadwinner Support.'));
            } 
        } catch(Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ' Error occurred  while fetching Products. Please try again or contact Breadwinner Support.'));
            System.debug('Products fetching failed.'+ex.getMessage()+'/n'+ex.getStackTraceString());            
        }
    }
    //Replacing standard Salesforce types in the JSON response 
    public String replaceStandardTypes(String str) {
        String replacedStr = '';
        if(str != null) replacedStr = str.replaceAll('"object"', '"stripe_object"').replaceAll('"currency"', '"stripe_currency"').replaceAll('"type"', '"stripe_type"');
        return replacedStr;
    }
    public class ProductsResponse {
        public List <Product> data         {get;set;}
    }
    public class Product {
        public String name                      {get; set;}
        public String active                    {get; set;}
        public String description               {get; set;}
        public String type                      {get; set;}
        public Long created                     {get; set;} 
    }
}
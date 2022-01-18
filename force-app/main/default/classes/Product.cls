public class Product {
    public class StripeProduct {
        public String id;
        public Boolean active;
        public Integer created;
        public String description;
        public String name;
        public String stripe_type;
    }
    public class StripePrice {
        public String id;
        public Boolean active;
        public Integer created;
        public String stripe_currency;
        public String product;
        public StripeRecurringPrice recurring;
        public String stripe_type;
        public Integer unit_amount;
    }
    public class StripeRecurringPrice {
        public String interval;
        public Integer interval_count;
    }
}
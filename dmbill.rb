require 'rubygems'
require 'mysql'
require 'pdf/writer'
require 'pdf/simpletable'
require 'date'

# everyday at 12 am

my = Mysql::new("localhost", "root", "justice", "delivery")


sql_company_count = "select count(*) from companies;"
company_count = (my.query sql_company_count).fetch_row.first


Integer(company_count).times { |n|


  sql_current_company = "select companies.name, companies.logo, companies.sms_price, companies.email, companies.start, (DATEDIFF(companies.start,CURRENT_DATE())) as ddiff from companies where companies.id = " + n.to_s + " and ((DATEDIFF(companies.start,CURRENT_DATE())) % 30)=0;"
  puts sql_current_company
  
  current_company_result = (my.query sql_current_company).fetch_row
  
  if not current_company_result.nil?
    company_name = current_company_result.first.to_s
    company_logo = current_company_result[1].to_s
    company_sms_price = current_company_result[2].to_s
    company_email = current_company_result[3].to_s
    company_start = current_company_result[4].to_s
    


    puts "======" + company_name
    puts "======" + company_logo
    puts "======" + company_sms_price
    puts "======" + company_email
    puts "======" + company_start

    pdf = PDF::Writer.new :orientation => :landscape
    table = PDF::SimpleTable.new
    pdf.select_font "Times-Roman"


    #i0 = pdf.image "images/" + company_logo, :resize => 0.75

    pdf.text "Delivery Magic Orders Report " + Date.today.to_s, :font_size => 35, :justification => :center

    #i1 = pdf.image "../images/chunkybacon.png", :justification => :center, :resize => 0.75
    #pdf.image i0, :justification => :right, :resize => 0.75


     
    latest_bill_expire_date = ""
    sql_get_latest_bill = "select * from bills where companies_id = " + n.to_s + " and payed = 1 order by expire desc;"
    sql_get_latest_bill_result = my.query sql_get_latest_bill
    latest_bill = sql_get_latest_bill_result.fetch_row
    if not latest_bill.nil? 
      puts "latest bill not nil"
      latest_bill_expire_date = latest_bill.first[2].to_s
    else
      puts "latest bill nil"
      latest_bill_expire_date = company_start
    end
    puts "====================" + latest_bill_expire_date


# select orders.id,orders.timestamp, addresses.address, orders.depto, orders.phone,orders.amount
# from orders,addresses where addresses.id = orders.addresses_id and orders.companies_id = 0 and (orders.timestamp < CURRENT_DATE()) and
# (orders.timestamp > DATE_SUB('-30',INTERVAL 10 DAYS));



    sql = "select orders.id,orders.timestamp, addresses.address, orders.depto, orders.phone,orders.amount,DATE_SUB('" + latest_bill_expire_date + "',INTERVAL 10 DAY) as billdate
           from orders,addresses
           where addresses.id = orders.addresses_id and 
                 companies_id = " + n.to_s + " and
                 orders.timestamp BETWEEN DATE_SUB('" + latest_bill_expire_date + "',INTERVAL 10 DAY) and now();"

    puts "==========" + sql
    sql_orders_count = "select count(*) from orders where companies_id = " + n.to_s + ";"
    orders_count = Integer((my.query sql_orders_count).fetch_row.first.to_s)


    res = my.query sql
    latest_bill_date = ""
    total = 0
    
    if not res.nil? and not res.fetch_row.nil? and res.fetch_row.size > 0
 
      table.data = []

      res.each do |row|
        col1 = row[1]
        col2 = row[2]
        col3 = row[3]
        col4 = row[4]
        col5 = row[5]
        latest_bill_date = row[6]
        puts latest_bill_date.to_s
        total = total + Float(col5)
        table.data.push "Date&Time" => col1.to_s,
                        "Address" => col2.to_s,
                        "Appartment" => col3.to_s,
                        "Mobile Phone" => col4.to_s,
                        "Amount" => col5.to_s
      end


      table.column_order = [ "Date&Time", "Address", "Appartment","Mobile Phone","Amount" ]
      table.render_on(pdf)




#@sql = "select orders.timestamp, addresses.address, orders.depto, orders.phone,orders.amount
#from orders,addresses,(select orders.id,products.name,products_orders.amount 
#                       from orders,products,products_orders
#                       where orders.id = products_orders.orders_id and
#                       products_orders.products_id = products.id) as ordered_products
#                       where addresses.id = orders.addresses_id and
#                       orders.id = ordered_products.id;"


      
      total_to_pay = (table.data.size*Float(company_sms_price)).to_s
 
      pdf.text "Price per order: " + company_sms_price, :font_size => 10, :justification => :right
      pdf.text "Processed amount: $" + total.to_s, :font_size => 10, :justification => :right
      pdf.text "Orders: " + orders_count.to_s, :justification => :right
      pdf.text "Total: $" + total_to_pay, :font_size => 25, :justification => :right


  


      pdf.save_as(company_name.gsub(" ","") + "-" + Date.today.to_s + ".pdf")
 

      



      sql_insert_into_bills = "insert into bills (amount,expire,companies_id) values (" + total_to_pay.to_s + "," + "DATE_ADD('" + latest_bill_date + "', INTERVAL 10 DAY)," + n.to_s + ");"
      puts sql_insert_into_bills
      my.query sql_insert_into_bills

    end
  end

}

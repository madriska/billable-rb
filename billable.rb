require 'rubygems'
require 'activerecord'

class Billable < ActiveRecord::Base
  self.abstract_class = true

  def self.open_file(filename='~/Library/Application Support/Billable/Billable.sqlite')
    filename = File.expand_path(filename)
    establish_connection :adapter => 'sqlite3',
      :database => filename
  end
  
  class Company < ::Billable
    set_table_name 'ZCOMPANY'
    set_primary_key 'Z_PK'
    has_many :services, :class_name => '::Billable::Service'

    alias_attribute :name, :ZNAME
    alias_attribute :hourly_rate, :ZDEFAULTHOURLYRATE
  end

  # FIXME: ZBASE actually contains invoices and services, disambiguated by a type field.
  # But I don't use invoices, so whatever.
  class Service < ::Billable
    set_table_name 'ZBASE'
    set_primary_key 'Z_PK'
    belongs_to :company, :class_name => '::Billable::Company',
      :foreign_key => :ZCLIENT1
    
    alias_attribute :summary,     :ZSUMMARY1
    alias_attribute :hourly_rate, :ZHOURLYRATE
    alias_attribute :seconds,     :ZTOTALTIMEINSECONDS
    alias_attribute :fixed_cost,  :ZTOTALFLATFEECOST
    alias_attribute :quantity,    :ZQUANTITYCOUNT
    alias_attribute :time,        :ZDATE1
    
    # Stored as seconds since Jan 1, 2000 @ midnight UTC.
    # I don't know if that's a Core Data thing or what, but we can 
    # work with it.
    def time
      sec = self.ZDATE1_before_type_cast.to_f
      self.class.core_data_epoch + sec
    end

    def hours
      BigDecimal.new(seconds.to_s) / 3600
    end
    
    def total
      amt = if self.ZRATETYPE == 2
        hourly_rate * seconds / 3600
      else
        fixed_cost * quantity
      end
      amt.round(2, BigDecimal::ROUND_HALF_EVEN) # banker's rounding
    end
    
    def self.core_data_epoch
      Time.at(0) + 31.years
    end

    def self.print_all
      find(:all, :order => 'ZDATE1 asc').each do |service|
        puts "#{service.company.name} #{service.time}: #{service.summary} ($#{service.total})"
      end
    end
    
    def self.find_all_by_date(date)
      find_all_by_dates(date..date)
    end

    def self.find_all_by_dates(range)
      begin_time = range.begin.midnight.to_time - core_data_epoch
      end_time = (range.end+1).midnight.to_time - core_data_epoch
      find(:all, :conditions => ['ZDATE1 BETWEEN ? AND ?', begin_time, end_time], :order => 'ZDATE asc')
    end

    def self.today
      find_all_by_date(Date.today)
    end
    
  end
end

begin
  Billable.open_file
rescue
end

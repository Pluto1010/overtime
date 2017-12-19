#!/usr/bin/env ruby
timelog_file = ARGV[0]

require 'json'
require 'open-uri'
require 'csv'
require 'table_print'

class Overtime
  attr_reader :current_year

  def initialize()
    @use_federal_state = "NW"
    @bank_holidays = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }
    @substracted_per_day = Hash.new { |h,k| h[k] = 0 }

    (first_year..current_year+1).each { |year| add_holidays("http://feiertage.jarmedia.de/api/?jahr=#{year}") }
  end

  def current_year
    @current_year ||= Date.today.year
  end

  def first_year
    2016
  end

  def add_holidays(url)
    holidays = JSON.load(open(url))

    holidays.each do |k, d|
      d.each do |bank_holiday_name, info|
        @bank_holidays[k][bank_holiday_name] << info['datum']
      end
    end
  end

  def bank_holiday?(date)
    date_string = date.strftime("%Y-%m-%d")

    @bank_holidays[@use_federal_state].each do |h,v|
      return true if v.include?(date_string)
    end

    return false
  end

  def weekend?(date)
    return date.wday == 0 || date.wday == 6
  end

  def calculate(timelog_file)
    result = []
    overall_overtime = 0;
    CSV.foreach(timelog_file, encoding: 'ISO8859-15:utf-8', col_sep: ';', headers: true) do |row|
    #  ap row
      date = Date.parse(row["Datum"])
      hours = row["Stunden"].gsub(',','.').to_f
      activity = row["Aktivität"]
      comment = row["Kommentar"]

      hours = 0 if activity == 'Holiday'

      bank_holiday = bank_holiday?(date)
      at_weekend = weekend?(date)

      overtime = hours

      substracted = 0
      unless @substracted_per_day.key?(date)
        unless at_weekend || bank_holiday ||  activity == 'Holiday'
          substract = -8
          overtime += substract
          @substracted_per_day[date] += 1
        end
      end

      result << {
        date: date,
        worktime: hours,
        overtime_hours: overtime,
        substract: substract,
        activity: activity,
        comment: comment,
        is_weekend: ("WEEKEND" if at_weekend),
        is_bank_holiday: ("BANK_HOLIDAY" if bank_holiday)
      }

      overall_overtime = overall_overtime + overtime
    end

    tp.set :separator, ";"
    tp result

    puts "Overtime: #{overall_overtime} h"
  end
end

instance = Overtime.new
instance.calculate(timelog_file)

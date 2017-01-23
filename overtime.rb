#!/usr/bin/env ruby
timelog_file = ARGV[0]

require 'json'
require 'open-uri'
require 'csv'
require 'table_print'

class Overtime
  def initialize()
    @use_federal_state = "NW"
    @bank_holidays = Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = [] } }

    add_holidays "http://feiertage.jarmedia.de/api/?jahr=2016"
    add_holidays "http://feiertage.jarmedia.de/api/?jahr=2017"
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

      bank_holiday = bank_holiday?(date)
      at_weekend = weekend?(date)

      overtime = hours
      overtime -= 8 unless at_weekend || bank_holiday

      result << {
        date: date,
        worktime: hours,
        overtime_hours: overtime,
        activity: activity,
        comment: comment,
        is_weekend: ("WEEKEND" if at_weekend),
        is_bank_holiday: ("BANK_HOLIDAY" if bank_holiday)
      }

      overall_overtime = overall_overtime + overtime
    end

    tp result

    puts "Overtime: #{overall_overtime}"
  end
end

instance = Overtime.new
instance.calculate(timelog_file)

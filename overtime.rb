#!/usr/bin/env ruby
timelog_file = ARGV[0]

require 'json'
require 'open-uri'
require 'csv'
require 'table_print'

class Overtime
  def initialize()
    @bank_holidays = JSON.load(open("http://feiertage.jarmedia.de/api/?jahr=2016"))
    @bank_holidays.merge! JSON.load(open("http://feiertage.jarmedia.de/api/?jahr=2017"))
    @use_bundesland = "NW"
  end

  def bank_holiday?(date)
    date_string = date.strftime("%Y-%m-%d")

    @bank_holidays[@use_bundesland].each do |h,v|
      return true if v["datum"] == date_string
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

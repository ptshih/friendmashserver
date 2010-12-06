def updateStatisticSummary
  query = "call update_statistic_summary();"
  mysqlresults = ActiveRecord::Base.connection.execute(query)
end


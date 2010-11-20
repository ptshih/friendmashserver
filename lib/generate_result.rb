class GenerateResult < Struct.new(:id, :winnerId, :loserId, :left, :mode, :winnerBeforeScore, :loserBeforeScore) 
  def perform
    Result.create(
      :facebook_id => id,
      :winner_id => winnerId,
      :loser_id => loserId,
      :left => left,
      :mode => mode,
      :winner_score => winnerBeforeScore,
      :loser_score => loserBeforeScore
    )
  end
end
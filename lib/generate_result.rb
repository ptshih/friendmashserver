class GenerateResult < Struct.new(:id, :winnerId, :loserId, :left, :mode, :winnerBeforeScore, :loserBeforeScore, :judgeFactor, :gender)
  # This delayed job class creates a Result entry for a given mash result
  def perform
    Result.create(
      :facebook_id => id,
      :winner_id => winnerId,
      :loser_id => loserId,
      :left => left,
      :mode => mode,
      :winner_score => winnerBeforeScore,
      :loser_score => loserBeforeScore,
      :judge_factor => judgeFactor,
      :gender => gender
    )
  end
end
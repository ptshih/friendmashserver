class GenerateResult < Struct.new(:params, :winner, :loser) 
  def perform
    Result.create(
      :facebook_id => params[:id],
      :winner_id => params[:w],
      :loser_id => params[:l],
      :left => params[:left],
      :mode => params[:mode],
      :winner_score => winner[:score],
      :loser_score => loser[:score]
    )
  end
end
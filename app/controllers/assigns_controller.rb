class AssignsController < ApplicationController
  before_action :authenticate_user!

  def create
    team = Team.friendly.find(params[:team_id])
    user = email_reliable?(assign_params) ? User.find_or_create_by_email(assign_params) : nil
    if user
      team.invite_member(user)
      redirect_to team_url(team), notice: I18n.t('views.messages.assigned')
    else
      redirect_to team_url(team), notice: I18n.t('views.messages.failed_to_assign')
    end
  end

  def update
    team = Team.friendly.find(params[:team_id])

    if current_user.id == team.owner_id
      assign_id = params[:id]
      assign = Assign.find(params[:id])
      team.owner_id = assign.user_id
      if team.save
        user = User.find(assign.user_id)
        AssignMailer.update_mail(user.email, team.name).deliver
        redirect_to team_url(team), notice: 'update success'
      else
        redirect_to team_url(team), notice: 'update miss'
      end
    else
      redirect_to team_url(team), notice: 'you can\'t grant owner'
    end
  end

  def destroy
    assign = Assign.find(params[:id])
    assigned_user = assign.user
    if assigned_user == assign.team.owner
      redirect_to team_url(params[:team_id]), notice: 'リーダーは削除できません。'
    elsif Assign.where(user_id: assigned_user.id).count == 1
      redirect_to team_url(params[:team_id]), notice: 'このユーザーはこのチームにしか所属していないため、削除できません。'
    elsif current_user != assign.team.owner && current_user != assign.user
      redirect_to team_url(params[:team_id]), notice: 'チームのリーダーか、ユーザー自身でない場合、削除できません。'
    else
      another_team = Assign.find_by(user_id: assigned_user.id).team
      change_keep_team(assigned_user, another_team) if assigned_user.keep_team_id == assign.team_id
      assign.destroy
      redirect_to team_url(params[:team_id]), notice: 'メンバーを削除しました。'
    end
  end
  private

  def assign_params
    params[:email]
  end

  def assign_destroy(assign, assigned_user)
    if assigned_user == assign.team.owner
      I18n.t('views.messages.cannot_delete_the_leader')
    elsif Assign.where(user_id: assigned_user.id).count == 1
      I18n.t('views.messages.cannot_delete_only_a_member')
    elsif assign.destroy
      set_next_team(assign, assigned_user)
      I18n.t('views.messages.delete_member')
    else
      I18n.t('views.messages.cannot_delete_member_4_some_reason')
    end
  end
  
  def email_reliable?(address)
    address.match(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
  end
  
  def set_next_team(assign, assigned_user)
    another_team = Assign.find_by(user_id: assigned_user.id).team
    change_keep_team(assigned_user, another_team) if assigned_user.keep_team_id == assign.team_id
  end
end

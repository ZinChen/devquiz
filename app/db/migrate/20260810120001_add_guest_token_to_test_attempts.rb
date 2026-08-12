class AddGuestTokenToTestAttempts < ActiveRecord::Migration[8.0]
  def change
    # Попытки гостей уже создаются с user_id: nil (RunsController пишет
    # current_user&.id), но найти их потом было нельзя. Токен из подписанной
    # куки позволяет присвоить их пользователю при первом входе.
    add_column :test_attempts, :guest_token, :string
    add_index  :test_attempts, :guest_token, where: "user_id IS NULL"
  end
end

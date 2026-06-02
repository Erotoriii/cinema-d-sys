class Users::RegistrationsController < Devise::RegistrationsController
  def create
    build_resource(sign_up_params)
    
    # Автоматично призначаємо роль "admin" для того, хто реєструє бізнес
    resource.role = 'admin'

    # Ініціалізуємо об'єкт Компанії
    company = Company.new(
      name: params[:company][:name],
      domain_prefix: params[:company][:domain_prefix]
    )

    # Перевіряємо, чи немає помилок у формах
    if company.valid? && resource.valid?
      ActiveRecord::Base.transaction do
        company.save!
        resource.company_id = company.id
        resource.save!
      end

      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      # Передаємо помилки компанії до загальних помилок форми
      company.errors.full_messages.each do |msg|
        resource.errors.add(:base, "Компанія: #{msg}")
      end
      clean_up_passwords resource
      set_minimum_password_length
      render :new, status: :unprocessable_entity
    end
  end
end
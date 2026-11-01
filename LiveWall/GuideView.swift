import SwiftUI

struct GuideView: View {

    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id = UUID()
        let number: String
        let title: String
        let text: String
        let icon: String
    }

    private let steps: [Step] = [
        Step(
            number: "1",
            title: "Создайте Live Photo",
            text: "На вкладке «Создать» выберите видео или фото и нажмите «Сделать Live Photo». Файл сохранится в приложение «Фото».",
            icon: "livephoto"
        ),
        Step(
            number: "2",
            title: "Откройте настройки обоев",
            text: "Настройки → Обои → «Добавить новые обои» → «Фото».",
            icon: "gearshape.fill"
        ),
        Step(
            number: "3",
            title: "Выберите Live Photo",
            text: "Найдите свежее фото: в его углу есть значок LIVE. Нажмите на него.",
            icon: "photo.stack.fill"
        ),
        Step(
            number: "4",
            title: "Включите анимацию",
            text: "Внизу экрана нажмите кнопку Live Photo, чтобы она стала активной (без перечёркивания).",
            icon: "play.circle.fill"
        ),
        Step(
            number: "5",
            title: "Установите обои",
            text: "Нажмите «Добавить» → «Установить как пару обоев». Готово!",
            icon: "checkmark.seal.fill"
        )
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(steps) { step in
                        stepCard(step)
                    }

                    notes
                    closeButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Как установить")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Пять шагов — и обои оживут")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.bottom, 4)
    }

    private func stepCard(_ step: Step) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.gradient)
                    .frame(width: 38, height: 38)

                Text(step.number)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: step.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent3)

                    Text(step.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(step.text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .card(padding: 16)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Полезно знать")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            noteRow(icon: "lock.fill", text: "iOS не позволяет приложениям менять обои напрямую — установка занимает несколько секунд вручную.")
            noteRow(icon: "hand.tap.fill", text: "На экране блокировки анимация запускается при пробуждении телефона или долгом нажатии.")
            noteRow(icon: "figure.walk.motion", text: "Если анимации нет, отключите «Настройки → Универсальный доступ → Движение → Уменьшение движения».")
            noteRow(icon: "clock.fill", text: "Live Photo длиннее 5 секунд система может обрезать или не принять.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Text("Понятно")
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 4)
    }
}

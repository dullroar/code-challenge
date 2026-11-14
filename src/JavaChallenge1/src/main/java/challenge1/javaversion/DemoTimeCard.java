package challenge1.javaversion;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "time_cards")
public class DemoTimeCard {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String category;
    private double hours;
    private String userId;
    private int year;
    private int week;
    private boolean isDemo;

    protected DemoTimeCard() {
    }

    public DemoTimeCard(String category, double hours, String userId, int year, int week, boolean isDemo) {
        this.category = category;
        this.hours = hours;
        this.userId = userId;
        this.year = year;
        this.week = week;
        this.isDemo = isDemo;
    }
}

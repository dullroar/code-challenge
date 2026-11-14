package challenge1.javaversion;

import java.awt.Color;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.temporal.IsoFields;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Random;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.locks.ReentrantLock;
import java.util.function.BooleanSupplier;
import java.util.stream.Stream;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.Timer;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.support.GenericXmlApplicationContext;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.data.repository.CrudRepository;
import org.springframework.util.ReflectionUtils;

// A Java + Spring port of Jim Lehmer's 2008 C# 3.0 challenge, following the 2026 .NET
// modernization at https://github.com/dullroar/code-challenge.
//
// The objective remains: make a small desktop program using exactly one Java statement - a
// for statement whose body is empty. The point is comparison, not production style.
//
// Substitutions from the .NET version:
//   - Spring Boot + Spring Data JPA + local SQLite rather than EF Core + SQLite.
//   - A Swing window described by Spring XML bean definitions built at runtime, rather
//     than a WPF window described by runtime XAML.
//   - Spring's ReflectionUtils rather than MethodInfo.Invoke.
//
// The program only writes clearly identified *demo* time cards into a SQLite database
// in the project's data directory. It is not connected to, and must not be used for, a real
// time-reporting system.
@SpringBootApplication
public class Program {

    public static void main(String[] args) throws Exception {
        for // Still the only statement.
        (
            // The anonymous class is the iterator-state wrapper, as the anonymous object was in
            // C#: the for initializer permits only one declaration, even when several types are
            // needed. `var` keeps the anonymous type, so its fields stay reachable.
            var i = new Object() {
                // The XML fragment is still deliberately gratuitous. It becomes part of the
                // Spring bean definitions below, as the XElement became part of the XAML.
                final String xmlAnim = """
                    <bean id="anim" class="javax.swing.Timer" init-method="start">
                      <constructor-arg value="40"/>
                      <constructor-arg><null/></constructor-arg>
                    </bean>
                    """;
                final List<Double> totalHours = new ArrayList<>();
                final String user = System.getProperty("user.name");
                final Path directory = Files.createDirectories(Path.of("data"));
                final ConfigurableApplicationContext ctx = new SpringApplicationBuilder(Program.class)
                    .web(WebApplicationType.NONE)
                    .headless(false)
                    .properties("spring.datasource.url=jdbc:sqlite:" + directory.resolve("demo-timecards.db"))
                    .run(args);
                final DemoTimeCardRepository timeCards = ctx.getBean(DemoTimeCardRepository.class);
                final List<DemoTimeCard> pending = new ArrayList<>();
                final Random rnd = ThreadLocalRandom.current();
                final Iterator<String> categories = List.of("Meetings", "Coding", "Debugging", "Learning").iterator();
                final ReentrantLock mutex = new ReentrantLock();
            }
                //   *
                //  *
        ;   // **************** FIRST SEMICOLON ****************
                //  *
                //   *
            // The stream stands in for LINQ to Objects. When the demo batch reaches
            // approximately one work week, show the result and terminate the loop.
            i.totalHours.stream().mapToDouble(Double::doubleValue).sum() <= 40d && i.categories.hasNext()
                ? true
                : ((BooleanSupplier) () -> Double.isNaN(
                    Stream.of(
                        new GenericXmlApplicationContext(
                            new ByteArrayResource(
                                ("""
                                <beans xmlns="http://www.springframework.org/schema/beans"
                                       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                       xsi:schemaLocation="http://www.springframework.org/schema/beans
                                           https://www.springframework.org/schema/beans/spring-beans.xsd">
                                  <bean id="banner" class="javax.swing.JLabel">
                                    <property name="text" value="DEMO ONLY - no real time system is involved"/>
                                    <property name="horizontalAlignment" value="0"/>
                                    <property name="foreground" value="#{T(java.awt.Color).decode('#FFCE56')}"/>
                                    <property name="font" value="#{new java.awt.Font('SansSerif', 1, 18)}"/>
                                  </bean>
                                  <bean id="total" class="javax.swing.JLabel">
                                    <property name="text" value="Total simulated hours: \
                                """ +
                                String.format("%.1f", i.totalHours.stream().mapToDouble(Double::doubleValue).sum()) +
                                """
                                "/>
                                    <property name="horizontalAlignment" value="0"/>
                                    <property name="foreground" value="#{T(java.awt.Color).WHITE}"/>
                                    <property name="font" value="#{new java.awt.Font('SansSerif', 1, 24)}"/>
                                  </bean>
                                  <bean id="saved" class="javax.swing.JLabel">
                                    <property name="text" value="Saved locally for the modernization exercise."/>
                                    <property name="horizontalAlignment" value="0"/>
                                    <property name="foreground" value="#{T(java.awt.Color).WHITE}"/>
                                    <property name="font" value="#{new java.awt.Font('SansSerif', 1, 18)}"/>
                                  </bean>
                                  <bean id="panel" class="javax.swing.JPanel">
                                    <constructor-arg value="#{new java.awt.BorderLayout()}"/>
                                    <property name="background" value="#{T(java.awt.Color).decode('#172033')}"/>
                                    <property name="border"
                                              value="#{T(javax.swing.BorderFactory).createEmptyBorder(24, 28, 40, 28)}"/>
                                  </bean>
                                  <bean class="org.springframework.beans.factory.config.MethodInvokingBean">
                                    <property name="targetObject" ref="panel"/>
                                    <property name="targetMethod" value="add"/>
                                    <property name="arguments"><list><ref bean="banner"/><value>North</value></list></property>
                                  </bean>
                                  <bean class="org.springframework.beans.factory.config.MethodInvokingBean">
                                    <property name="targetObject" ref="panel"/>
                                    <property name="targetMethod" value="add"/>
                                    <property name="arguments"><list><ref bean="total"/><value>Center</value></list></property>
                                  </bean>
                                  <bean class="org.springframework.beans.factory.config.MethodInvokingBean">
                                    <property name="targetObject" ref="panel"/>
                                    <property name="targetMethod" value="add"/>
                                    <property name="arguments"><list><ref bean="saved"/><value>South</value></list></property>
                                  </bean>
                                  <bean id="window" class="javax.swing.JDialog">
                                    <constructor-arg type="java.awt.Window"><null/></constructor-arg>
                                    <property name="title" value="Only One STATEMENT (Java + Spring demo)"/>
                                    <property name="modal" value="true"/>
                                    <property name="size" value="#{new java.awt.Dimension(520, 320)}"/>
                                    <property name="resizable" value="false"/>
                                    <property name="defaultCloseOperation" value="2"/>
                                    <property name="contentPane" ref="panel"/>
                                  </bean>
                                """ +
                                i.xmlAnim +
                                "</beans>").getBytes(StandardCharsets.UTF_8))))
                        // The pulse: every label fades from opaque to 45% and back, 1.2 seconds each way.
                        .peek(xml -> xml.getBean(Timer.class).addActionListener(
                            tick -> xml.getBeansOfType(JLabel.class).values().forEach(
                                label -> label.setForeground(
                                    new Color(
                                        label.getForeground().getRed(),
                                        label.getForeground().getGreen(),
                                        label.getForeground().getBlue(),
                                        (int) (255 * (0.45 + 0.55 * Math.abs(System.nanoTime() / 1e9 % 2.4 / 1.2 - 1))))))))
                        .peek(xml -> xml.getBean(JDialog.class).setLocationRelativeTo(null))
                        // A modal dialog blocks here until it is closed, as Application.Run did.
                        .peek(xml -> xml.getBean(JDialog.class).setVisible(true))
                        .peek(xml -> xml.getBean(Timer.class).stop())
                        .peek(GenericXmlApplicationContext::close)
                        .mapToInt(xml -> 0)
                        .sum())).getAsBoolean()
               //   *
               //  *
        ;  // **************** LAST SEMICOLON ****************
               //  *
               //   *
            // The data access shape intentionally resembles Add/SaveChanges: the loop stages a
            // record and a background thread saves it. The lock keeps the save from overlapping
            // the next add.
            i.mutex.lock(),
            i.totalHours.add((double) i.rnd.nextInt(10, 20)),
            i.pending.add(
                new DemoTimeCard(
                    i.categories.next(),
                    i.totalHours.getLast(),
                    i.user,
                    LocalDate.now().getYear(),
                    LocalDate.now().get(IsoFields.WEEK_OF_WEEK_BASED_YEAR),
                    true)),
            i.mutex.unlock(),
            // The gratuitous background thread and reflection are retained as a historic contrast.
            new Thread(
                () -> new StringBuilder(
                    "" +
                    ReflectionUtils.invokeMethod(
                        ReflectionUtils.findMethod(ReentrantLock.class, "lock"), i.mutex) +
                    ReflectionUtils.invokeMethod(
                        ReflectionUtils.findMethod(CrudRepository.class, "saveAll", Iterable.class), i.timeCards, i.pending) +
                    ReflectionUtils.invokeMethod(
                        ReflectionUtils.findMethod(ReentrantLock.class, "unlock"), i.mutex)).toString())
                .start()
        )
        { /* Intentionally empty. */ }
    }
}

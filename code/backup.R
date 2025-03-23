
Consider two hypotheses - a null and an alternative hypothesis. As long as we sample a population, the two will always overlap (even if that overlap is really small).

```{r echo = FALSE, warning = FALSE}
tibble(x = c(-15, 15)) %>%
  ggplot(aes(x = x)) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, colour = "blue", n = 40) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, colour = "darkgreen", n = 40) +
  theme_void() +
  annotate("text", x = -5, y = .07, label = expression("Null hypothesis"~H[0])) +
  annotate("text", x = 5, y = .07, label = expression("Alternate\nhypothesis"~H[1]))

```



The area shaded in bright green below represents where the two distributions overlap with each other. This is where the null hypothesis might be rejected when it shouldn't be, or vice versa.

```{r echo = FALSE, warning = FALSE}
tibble(x = c(-15, 15)) %>%
  ggplot(aes(x = x)) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, colour = "blue", n = 40) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, colour = "darkgreen", n = 40) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, fill = "green", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c(0, 5)) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, fill = "green", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c(0, -5)) +
  theme_void() +
  annotate("text", x = -5, y = .07, label = expression("Null hypothesis"~H[0])) +
  annotate("text", x = 5, y = .07, label = expression("Alternate\nhypothesis"~H[1]))

```
Let's assume an alpha of .05, and divide this region accordingly. There is a certain probability of alpha (where the null is incorrectly rejected), as well as a probability of beta (where the null is not rejected when it should be).


```{r echo = FALSE, warning = FALSE}

tibble(x = c(-15, 15)) %>%
  ggplot(aes(x = x)) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, colour = "blue", n = 40) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, colour = "darkgreen", n = 40) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, fill = "lightblue", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c(qnorm(p = .975, mean = -5, sd = 3), 5)) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, fill = "lightgreen", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c(1 - (qnorm(p = .05, mean = 5, sd = 3)), -5)) +
  theme_void() +
  annotate("text", x = -.5, y = .005, label = expression(beta)) +
  annotate("text", x = 1.5, y = .005, label = expression(alpha))+
  annotate("text", x = -5, y = .07, label = expression("Null hypothesis"~H[0])) +
  annotate("text", x = 5, y = .07, label = expression("Alternate\nhypothesis"~H[1]))
```


What happens if we were to decrease alpha? (i.e. reduce our Type I error rate)? All else being equal (sample size, effect size etc), we can see that alpha now takes up less space in the overlapping area - and so, beta (Type II error) will increase.

```{r echo = FALSE, warning = FALSE}
tibble(x = c(-15, 15)) %>%
  ggplot(aes(x = x)) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, colour = "blue", n = 40) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, colour = "darkgreen", n = 40) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, fill = "lightblue", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c(qnorm(p = .99, mean = -5, sd = 3), 5)) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, fill = "lightgreen", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c((qnorm(p = .99, mean = -5, sd = 3)), -5)) +
  theme_void() +
  annotate("text", x = 0, y = .005, label = expression(beta)) +
  annotate("text", x = 2.5, y = .003, label = expression(alpha))+
  annotate("text", x = -5, y = .07, label = expression("Null hypothesis"~H[0])) +
  annotate("text", x = 5, y = .07, label = expression("Alternate\nhypothesis"~H[1]))
```

Subsequently, if we were to increase alpha we can see the opposite; beta will decrease, because now the overlap is predominantly now covered by the rejection region covered by alpha.

```{r echo = FALSE, warning = FALSE}
tibble(x = c(-15, 15)) %>%
  ggplot(aes(x = x)) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, colour = "blue", n = 40) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, colour = "darkgreen", n = 40) +
  stat_function(fun = dnorm, args = list(mean = -5, sd = 3), 
                size = 1, fill = "lightblue", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c(qnorm(p = .90, mean = -5, sd = 3), 5)) +
  stat_function(fun = dnorm, args = list(mean = 5, sd = 3), 
                size = 1, fill = "lightgreen", geom = "area", 
                alpha = 0.5, n = 40, 
                xlim = c((qnorm(p = .90, mean = -5, sd = 3)), -5)) +
  theme_void() +
  annotate("text", x = -2, y = .005, label = expression(beta)) +
  annotate("text", x = 1, y = .005, label = expression(alpha))+
  annotate("text", x = -5, y = .07, label = expression("Null hypothesis"~H[0])) +
  annotate("text", x = 5, y = .07, label = expression("Alternate\nhypothesis"~H[1]))
```

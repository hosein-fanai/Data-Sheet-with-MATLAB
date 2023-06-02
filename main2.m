%driver code
function main2()
    clc
    clear
    close all
    
    vals_size = 100;
    
    blueprint.value = 0;
    blueprint.is_assigned = false;
    blueprint.expression = [];
    blueprint.dependencies = [];
    vals = repmat(blueprint ,vals_size ,vals_size);

    current_index = 'A1';
    
    while(true)
        %render ui
        clc
        print(vals ,current_index);
        input_command = input([upper(current_index) ,'>>'] ,'s');

        try %execute user's command
            [current_index ,vals] = parse_input(input_command ,vals ,current_index);
        catch 
            %on_hold('Error in input command! Try again. ')
        end
    end
    
end

%renders output
function print(vals ,curr)
    %computing limits of rendering area
    [i_curr ,j_curr] = parse_index(curr);
    if i_curr < 6
        i_low = 1;
        i_high = i_curr+5+(6-i_curr); %11
    elseif i_curr > 95
        i_low = i_curr-5+(95-i_curr); %90
        i_high = 100;
    else
        i_low = i_curr-5;
        i_high = i_curr+5;
    end
    if j_curr < 6
        j_low = 1;
        j_high = j_curr+5+(6-j_curr); %11
    elseif j_curr > 95
        j_low = j_curr-5+(95-j_curr); %90
        j_high = 100;
    else
        j_low = j_curr-5;
        j_high = j_curr+5;
    end
    
    %Rendering table
    flag = true;
    for i=i_low:i_high
        %printing first row (  A B C ... ) for once
        if flag
            fprintf('\t\t\t\t');
            for k=j_low:j_high
                m = mod(k ,26);
                row = char(m+64);
                if ~m
                    row = char(90);
                end
                l = floor((k-1)/26);
                if l
                    row = [char(64+l) ,row];
                end
                fprintf('%s\t\t\t\t' ,row);
            end
            flag = false;
            fprintf('\n');
        end
        %printing main values
        fprintf('%d\t\t\t\t' ,i);
        for j=j_low:j_high
            val = vals(i ,j);
            if val.is_assigned
                fprintf('%s\t\t\t\t' ,num2str(val.value));
            else
                fprintf('\t\t\t\t'); %Not printing not-assigned-values
            end
        end
        fprintf('\n');
    end

end

%parses user input
function [next ,vals_new] = parse_input(cmd ,vals ,curr)
    switch(cmd(1))
        case '='
            vals_new = action_assign(cmd ,vals ,curr);
            next = curr;

        case 'g'
            if cmd(1:4) == 'goto'
                next = action_goto(cmd ,vals ,curr);
                vals_new = vals;
            end

        case 's'
            if cmd(1:4) == 'save'
                action_save(cmd ,vals);
                next = curr;
                vals_new = vals;

            elseif cmd(1:4) == 'show'
                action_show(cmd ,vals);
                next = curr;
                vals_new = vals;

            end

        case 'l'
            if cmd(1:4) == 'load'
                vals_new = action_load(cmd);
                next = curr;
            end

        case 'q'
            if cmd(1:4) == 'quit'
                action_quit();
            end

    end

end

%parses string indexes to i,j
function [i ,j] = parse_index(ind)
    ind = upper(ind);
    first = [];
    second = [];
    for k=1:size(ind ,2)
        if isnan(str2double(ind(k)))
            first = [first ,ind(k)];
        else
            second = [second ,ind(k)];
        end
    end
    
    i = str2double(second);
    j=0;
    for k=1:size(first ,2)
        temp1 = double(first(k)) - double('a');
        temp2 = double(first(k)) - double('A');
        temp3 = max([temp1 ,temp2]) + 1;
        temp4 = temp3 * (26 ^ (size(first ,2) - k));
        j = j + temp4;         
                
    end
    
end

%actions
%1
function [vals_new] = action_assign(cmd ,vals ,curr)
    is_expression = false;
    val = [];
    expr = [];
    for i=2:size(cmd ,2)
        if isnan(str2double(cmd(i)))
            is_expression = true;
            expr = [expr ,val ,cmd(i)];
            val = [];
        else
            val = [val ,cmd(i)];
        end
    end
    
    [i_curr ,j_curr] = parse_index(curr);
    if is_expression
        expr = [expr ,val];
        if contains(upper(expr) ,upper(curr)) %recursive refrencing is illigal
            on_hold('Cannot refrence a cell to itself. ');
            vals_new = vals;
            return
        end
        
        vals(i_curr ,j_curr).expression = expr;
        vals(i_curr ,j_curr).value = evaluate_expression(expr ,vals);
        
        %todo : delete all dependencies that inculde curr index
        deps = find_dependencies_on_expr(expr);
        for i=1:numel(deps)
            [i_dep ,j_dep] = parse_index(deps(i));
            vals(i_dep ,j_dep).dependencies = [vals(i_dep ,j_dep).dependencies ,curr];
        end
        
    else
        vals(i_curr ,j_curr).value = str2double(val);
        vals(i_curr ,j_curr).expression = [];
        vals(i_curr ,j_curr).is_dependent = false;
        
    end
    vals(i_curr ,j_curr).is_assigned = true;
    
    vals_new = event_handler(curr ,vals);
    
end
%2
function [next] = action_goto(cmd ,vals ,curr)
    index = cmd(6:end);
    [i_curr ,j_curr] = parse_index(index);

    if i_curr > size(vals ,1) || j_curr > size(vals ,2)
        on_hold('Wrong item entered! ');
        next = curr;
        return
    end
    
    next = index;

end
%3
function action_save(cmd ,vals)
    dest = cmd(6:end);
    if dest(1) == "'"
        dest = dest(2:end-1);
    end
    save(dest ,'vals');
    on_hold(['Saved ' ,dest ,' file. ']);

end
%4
function [vals] = action_load(cmd)
    dest = cmd(6:end);
    if dest(1) == "'"
        dest = dest(2:end-1);
    end
    load(dest ,'vals');
    on_hold(['File ' ,dest ,' loaded. ']);

end
%5
function action_quit()
    quit;
    
end
%6
function action_show(cmd ,vals)
    index = cmd(6:end);
    [i ,j] = parse_index(index);
    if vals(i ,j).expression
        fprintf('%s\n' ,vals(i ,j).expression);
        on_hold();
    else
        on_hold('No expression yet! ');
    end
    
end

%handles events
function [new_vals] = event_handler(curr ,vals)
    [i_curr ,j_curr] = parse_index(curr);
    for i=1:numel(vals(i_curr ,j_curr).dependencies)
        dep = vals(i_curr ,j_curr).dependencies(i);
        [i_dep ,j_dep] = parse_index(dep);
        vals(i_dep ,j_dep).value = evaluate_expression(vals(i_dep ,j_dep).expression ,vals);

    end
    new_vals = vals;

end

%waits for any key to proceed
function on_hold(message)
    arguments
        message = ''
    end

    input([message ,'Press any key to continue.']);
    
end

%gets value of an expression
function [value] = evaluate_expression(expr ,vals)
    corrected_expr = [];
    i = 1;
    while i <= size(expr ,2)
        if ~isnan(str2double(expr(i))) || ~isletter(expr(i)) %only numbers or math signs
            corrected_expr = [corrected_expr ,expr(i)];

        else %found a letter
            if i+3 <= size(expr ,2) & expr(i:i+3) == 'mean'
                corrected_expr = [corrected_expr ,'mean('];
                ind = expr(i+5 : find(expr(i+5:end) == ')')+i+3);
                i = i + numel(ind) + 5;
                ind = translate_index(ind ,vals);
                corrected_expr = [corrected_expr ,ind ,')'];
                
            elseif i+3 <= size(expr ,2) & expr(i:i+2) == 'max'
                corrected_expr = [corrected_expr ,'max('];
                ind = expr(i+4 : find(expr(i+4:end) == ')')+i+2);
                i = i + numel(ind) + 4;
                ind = translate_index(ind ,vals);
                corrected_expr = [corrected_expr ,ind ,')'];
                
            elseif i+3 <= size(expr ,2) & expr(i:i+2) == 'min'
                corrected_expr = [corrected_expr ,'min('];
                ind = expr(i+4 : find(expr(i+4:end) == ')')+i+2);
                i = i + numel(ind) + 4;
                ind = translate_index(ind ,vals);
                corrected_expr = [corrected_expr ,ind ,')'];
                  
            else %regular index
                temp = find(expr(i:end) == '+' ...
                    | expr(i:end) == '*' ...
                    | expr(i:end) == '-' ... 
                    | expr(i:end) == '/' ...
                    | expr(i:end) == '%' ...
                    | expr(i:end) == '^' ...
                    | expr(i:end) == '\' ...
                    ) + i - 2;
                if size(temp ,2) == 0
                    temp = size(expr ,2);
                end
                ind = expr(i : temp);
                i = i + numel(ind) - 1;
                ind = translate_index(ind ,vals);
                corrected_expr = [corrected_expr ,ind];
                    
            end
        end
        i = i + 1;
    end
    
    value = eval(corrected_expr);

end

%determines expression dependency to other cells
function [deps] = find_dependencies_on_expr(expr)
    
end

%translates user given index to eval function understandable index
function [new_index] = translate_index(index ,vals)
    index_blueprint.i = []; %row
    index_blueprint.j = []; %columnn
    index_blueprint.k = []; %one dimensional indexing
    indeces = repmat(index_blueprint ,1 ,2);
    
    ind = [];
    for i=1:size(index ,2)
        if index(i) == ':'
            [indeces(1).i ,indeces(1).j] = parse_index(ind);
            ind = [];
        else
            ind = [ind ,index(i)];
        end
    end
    [indeces(2).i ,indeces(2).j] = parse_index(ind);
    
    indeces(1).k = (indeces(1).j-1)*size(vals ,1) + indeces(1).i;
    indeces(2).k = (indeces(2).j-1)*size(vals ,1) + indeces(2).i;
    
    if indeces(1).i
        %sorting indeces for users entering indeces backwards
        sorted_indeces = sort([indeces(1).k ,indeces(2).k]);
        indeces(1).k = sorted_indeces(1);
        indeces(2).k = sorted_indeces(2);

        new_index = [num2str(indeces(1).k) ,':' ,num2str(indeces(2).k)];
    else
        new_index = num2str(indeces(2).k);
    end
    
    new_index = ['[vals(', new_index, ').value]']; %usable index in eval function
    
end






